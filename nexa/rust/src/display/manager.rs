//! Central Display Manager (`manager.rs`)
//!
//! The single orchestration point that ties together all display subsystem modules.
//! Consumes `DisplayEvent`s from `events.rs`, computes `LayoutPlan`s via `planner.rs`,
//! validates them in `safety.rs`, and atomically applies them through `backend.rs`.
//!
//! ## Concurrency model
//!
//! - A single `Mutex<()>` (`op_lock`) serializes all plan executions so that
//!   concurrent hotplug events and user CLI requests cannot race against each other.
//! - The shared `HardwareSnapshot` is held under its own `Mutex` so callers can
//!   inspect the last known state without acquiring the heavy op-lock.
//! - The shared `DisplayConfigStore` is held under its own `Mutex` for the same reason.
//!
//! ## Feedback-loop suppression
//!
//! Applying a layout emits `monitoradded`/`monitorremoved` events from Hyprland itself.
//! To prevent those from retriggering the manager, every successful apply sets
//! `suppress_until = Instant::now() + SUPPRESS_WINDOW`. Events that arrive before that
//! deadline are silently discarded. A `ForceRefresh` always bypasses suppression.
//!
//! ## Clamshell persistence policy
//!
//! A clamshell transition (lid closed → ExternalOnly) is triggered automatically and
//! must NOT overwrite the user's saved topology profile. Only explicit `UserModeRequested`
//! events call `record_successful_topology`.

use crate::display::backend;
use crate::display::config::DisplayConfigStore;
use crate::display::events::spawn_event_listener;
use crate::display::model::{
    DisplayError, DisplayEvent, ExtendDirection, HardwareSnapshot, LayoutPlan, LidState,
    ProjectionMode,
};
use crate::display::planner::build_layout_plan;
use crate::display::safety::{build_emergency_fallback_plan, validate_plan, verify_applied_state};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

/// How long after a successful apply to suppress hotplug feedback events.
const SUPPRESS_WINDOW: Duration = Duration::from_millis(1200);

/// How long to wait for the compositor to settle before verifying applied state.
const SETTLE_DELAY: Duration = Duration::from_millis(350);

/// Maximum number of verify retries after an apply.
const VERIFY_RETRIES: u32 = 3;

// ---------------------------------------------------------------------------
// DisplayManager
// ---------------------------------------------------------------------------

pub struct DisplayManager {
    config_path: PathBuf,
    store: Arc<Mutex<DisplayConfigStore>>,
    snapshot: Arc<Mutex<HardwareSnapshot>>,
    /// Serializes every plan-execution so concurrent events cannot race.
    op_lock: Mutex<()>,
    /// Suppress monitoradded/monitorremoved feedback until this instant.
    suppress_until: Mutex<Instant>,
}

impl DisplayManager {
    /// Creates a new `DisplayManager`, loading persistent config from disk.
    ///
    /// If the config file is missing, `Default` is used. If the file exists but
    /// is malformed, it is renamed to `.bak` and `Default` is returned — startup
    /// never fails because of a corrupted config file (fixed in config.rs).
    ///
    /// The initial hardware snapshot is captured from Hyprland + kernel sysfs.
    pub fn new(config_path: &Path) -> Result<Arc<Self>, DisplayError> {
        // `load_from_path` already handles malformed files and falls back to Default.
        let store = DisplayConfigStore::load_from_path(config_path)?;

        // Capture initial hardware state (session_locked = false at startup).
        let snapshot = backend::capture_snapshot(false)?;

        Ok(Arc::new(Self {
            config_path: config_path.to_path_buf(),
            store: Arc::new(Mutex::new(store)),
            snapshot: Arc::new(Mutex::new(snapshot)),
            op_lock: Mutex::new(()),
            suppress_until: Mutex::new(Instant::now()),
        }))
    }

    // ---------------------------------------------------------------------------
    // Background event loop
    // ---------------------------------------------------------------------------

    /// Spawns the background event-listening threads and begins processing events.
    ///
    /// This method blocks the calling thread indefinitely (intended to be run in its own
    /// `std::thread` or as the daemon main loop). The loop only exits when the event
    /// channel closes, which should not happen under normal operation.
    pub fn run_background_loop(self: Arc<Self>) {
        let rx = spawn_event_listener();

        for event in rx {
            if let Err(e) = self.handle_event(event) {
                eprintln!("[NexaDisplay] Event handling error: {e}");
            }
        }

        eprintln!("[NexaDisplay] Event channel closed; manager shutting down.");
    }

    // ---------------------------------------------------------------------------
    // Event handling
    // ---------------------------------------------------------------------------

    /// Routes a single `DisplayEvent` to the correct handler.
    ///
    /// `HotplugChanged`, `LidChanged`, and `PowerChanged` may be suppressed during the
    /// post-apply quiet window. `ForceRefresh` and `UserModeRequested` always proceed.
    pub fn handle_event(&self, event: DisplayEvent) -> Result<(), DisplayError> {
        match &event {
            // ForceRefresh always bypasses suppression (snapshot reconciliation at startup
            // and after config reload).
            DisplayEvent::ForceRefresh => {
                return self.reconcile_from_hardware(false);
            }

            // User explicitly requested a mode change → always proceed, always persist.
            DisplayEvent::UserModeRequested { mode, direction } => {
                return self.apply_mode(*mode, *direction);
            }

            // Session lock changes update the snapshot but do not trigger a layout change.
            DisplayEvent::SessionLockChanged(locked) => {
                if let Ok(mut snap) = self.snapshot.lock() {
                    snap.session_locked = *locked;
                }
                return Ok(());
            }

            // All other events (HotplugChanged, LidChanged, PowerChanged) may be suppressed.
            _ => {}
        }

        // Check suppression window.
        let suppress_until = *self.suppress_until.lock().unwrap();
        if Instant::now() < suppress_until {
            return Ok(());
        }

        // Detect lid-close to set the clamshell flag so we don't persist the auto-mode.
        let is_clamshell = matches!(&event, DisplayEvent::LidChanged(LidState::Closed));

        // Re-read hardware and reconcile.
        self.reconcile_from_hardware(is_clamshell)
    }

    // ---------------------------------------------------------------------------
    // Core execution lifecycle
    // ---------------------------------------------------------------------------

    /// Re-reads hardware state from Hyprland + sysfs, then computes and applies the
    /// correct layout plan according to the current config and hardware topology.
    ///
    /// Set `is_clamshell` to `true` when the trigger was an automatic lid-close event;
    /// that prevents the resulting mode from being persisted to the topology profile.
    fn reconcile_from_hardware(&self, is_clamshell: bool) -> Result<(), DisplayError> {
        // 1. Capture fresh snapshot
        let session_locked = self
            .snapshot
            .lock()
            .map(|s| s.session_locked)
            .unwrap_or(false);
        let snapshot = backend::capture_snapshot(session_locked)?;

        // Update cached snapshot early so other callers see a recent view.
        if let Ok(mut guard) = self.snapshot.lock() {
            *guard = snapshot.clone();
        }

        // 2. Build layout plan (resolve_desired_mode is called inside build_layout_plan)
        let plan = {
            let store = self.store.lock().unwrap();
            build_layout_plan(&snapshot, &store, None, None)?
        };

        // 3. Resolve the effective direction for persistence recording
        let mode = plan.mode;
        let direction = {
            let store = self.store.lock().unwrap();
            store.resolve_desired_mode(&snapshot).1
        };

        // 4. Validate and execute
        self.execute_plan(plan, &snapshot, mode, direction, is_clamshell)
    }

    /// Handles an explicit user-requested mode change.
    ///
    /// Differs from `reconcile_from_hardware` in that:
    /// - The requested mode is passed directly (bypasses `resolve_desired_mode`).
    /// - On success, the topology is persisted to the config file.
    pub fn apply_mode(
        &self,
        mode: ProjectionMode,
        direction: Option<ExtendDirection>,
    ) -> Result<(), DisplayError> {
        let session_locked = self
            .snapshot
            .lock()
            .map(|s| s.session_locked)
            .unwrap_or(false);
        let snapshot = backend::capture_snapshot(session_locked)?;

        if let Ok(mut guard) = self.snapshot.lock() {
            *guard = snapshot.clone();
        }

        let resolved_direction = direction.unwrap_or_else(|| {
            self.store
                .lock()
                .map(|s| s.default_extend_direction)
                .unwrap_or_default()
        });

        let plan = {
            let store = self.store.lock().unwrap();
            build_layout_plan(&snapshot, &store, Some(mode), Some(resolved_direction))?
        };

        // User-initiated → always persist.
        self.execute_plan(plan, &snapshot, mode, resolved_direction, false)
    }

    /// Core execution pipeline: validate → acquire op-lock → apply → verify → persist.
    fn execute_plan(
        &self,
        plan: LayoutPlan,
        snapshot: &HardwareSnapshot,
        mode: ProjectionMode,
        direction: ExtendDirection,
        is_clamshell: bool,
    ) -> Result<(), DisplayError> {
        // Step 1: Pre-flight validation (pure, no I/O)
        validate_plan(&plan, snapshot)?;

        // Step 2: Acquire op-lock — serialise execution, prevent concurrent races
        let _guard = self.op_lock.lock().unwrap();

        // Step 3: Lid inhibition
        backend::set_lid_inhibit_active(plan.hold_lid_inhibit);

        // Step 4: Apply the layout
        backend::apply_layout_plan(&plan)?;

        // Step 5: Set suppression window BEFORE yielding (so the first feedback event
        // from Hyprland is already within the window)
        {
            let mut sup = self.suppress_until.lock().unwrap();
            *sup = Instant::now() + SUPPRESS_WINDOW;
        }

        // Step 6: Wait for compositor to settle, then verify applied state with retry
        let post_snapshot =
            self.verify_with_retry(snapshot.session_locked, &plan, VERIFY_RETRIES)?;

        // Update snapshot cache with the verified state
        if let Ok(mut guard) = self.snapshot.lock() {
            *guard = post_snapshot.clone();
        }

        // Step 7: Persist topology ONLY for explicit user requests (not clamshell auto-triggers)
        if !is_clamshell {
            let mut store = self.store.lock().unwrap();
            store.record_successful_topology(&post_snapshot, mode, direction);
            if let Err(e) = store.save_to_path(&self.config_path) {
                eprintln!("[NexaDisplay] Failed to persist config: {e}");
                // Non-fatal: the in-memory store is still correct.
            }
        }

        eprintln!(
            "[NexaDisplay] Applied mode={mode} direction={direction:?} persist={}",
            !is_clamshell
        );
        Ok(())
    }

    /// Waits for the compositor to settle, then verifies the applied state.
    /// Retries up to `max_retries` times with a fixed `SETTLE_DELAY` between attempts.
    fn verify_with_retry(
        &self,
        session_locked: bool,
        plan: &LayoutPlan,
        max_retries: u32,
    ) -> Result<HardwareSnapshot, DisplayError> {
        let mut last_err = DisplayError::IpcError("verify never ran".into());

        for attempt in 0..=max_retries {
            std::thread::sleep(SETTLE_DELAY);

            match backend::capture_snapshot(session_locked) {
                Ok(snap) => match verify_applied_state(&snap, plan) {
                    Ok(()) => return Ok(snap),
                    Err(e) => {
                        eprintln!(
                            "[NexaDisplay] Verify attempt {}/{max_retries} failed: {e}",
                            attempt + 1
                        );
                        last_err = e;
                    }
                },
                Err(e) => {
                    eprintln!(
                        "[NexaDisplay] Snapshot attempt {}/{max_retries} failed: {e}",
                        attempt + 1
                    );
                    last_err = e;
                }
            }
        }

        Err(last_err)
    }

    // ---------------------------------------------------------------------------
    // Emergency fallback
    // ---------------------------------------------------------------------------

    /// Executes the emergency fallback plan in a best-effort manner.
    ///
    /// This is deliberately infallible and does not propagate errors — the goal is
    /// to ensure at least one display remains usable no matter what.
    pub fn execute_emergency_fallback(&self) {
        let snapshot = backend::capture_snapshot(false).ok();
        let fallback_plan = build_emergency_fallback_plan(snapshot.as_ref());

        eprintln!("[NexaDisplay] Executing emergency fallback plan…");

        // Release lid inhibit first — if we're falling back, we want the system
        // to resume normal lid-close behaviour.
        backend::set_lid_inhibit_active(false);

        // Try to apply. Individual workspace migration failures inside
        // `apply_layout_plan` are best-effort (non-fatal, fixed in backend.rs).
        if let Err(e) = backend::apply_layout_plan(&fallback_plan) {
            eprintln!("[NexaDisplay] Emergency apply failed: {e}; trying blind eDP-1 enable…");

            // Last resort: send a single keyword to re-enable eDP-1 at origin.
            let _ = backend::hyprctl_command(
                r#"eval hl.monitor({ output = "eDP-1", disabled = false, mode = "preferred", position = "0x0", scale = 1.0, transform = 0 })"#,
            );
            let _ = backend::hyprctl_command("keyword monitor eDP-1,preferred,0x0,1");
        }

        // Invalidate the suppression window so the next event is processed normally.
        if let Ok(mut sup) = self.suppress_until.lock() {
            *sup = Instant::now();
        }
    }

    // ---------------------------------------------------------------------------
    // Inspection helpers (for CLI / IPC query commands)
    // ---------------------------------------------------------------------------

    /// Returns a clone of the last known `HardwareSnapshot`.
    pub fn last_snapshot(&self) -> HardwareSnapshot {
        self.snapshot.lock().map(|s| s.clone()).unwrap_or_default()
    }

    /// Returns the current resolved `(ProjectionMode, ExtendDirection)` for the active topology.
    pub fn current_mode(&self) -> (ProjectionMode, ExtendDirection) {
        let snap = self.last_snapshot();
        self.store
            .lock()
            .map(|s| s.resolve_desired_mode(&snap))
            .unwrap_or_default()
    }

    /// Returns `true` if the display manager is currently suppressing feedback events.
    pub fn is_suppressing(&self) -> bool {
        self.suppress_until
            .lock()
            .map(|t| Instant::now() < *t)
            .unwrap_or(false)
    }
}
