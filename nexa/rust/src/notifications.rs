use serde::{Deserialize, Serialize};

use std::{
    collections::HashMap,
    env,
    fs,
    path::PathBuf,
    sync::{
        atomic::{AtomicU32, Ordering},
        Arc, Mutex,
    },
    time::{SystemTime, UNIX_EPOCH},
};

use zbus::{
    interface,
    object_server::SignalEmitter,
    zvariant::OwnedValue,
    Connection,
};

use std::path::Path;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationTransientEvent {
    pub serial: u64,
    pub id: u32,

    pub app_name: String,
    pub app_icon: String,

    pub summary: String,
    pub body: String,

    pub timestamp: u64,
    pub timeout_ms: u64,
}
// ============================================================
// NEXA NOTIFICATION BACKEND
//
// Rust owns:
// - D-Bus notification service
// - notification IDs
// - notification history
// - replacement
// - dismissal
// - clear-all
// - persistent/shared state
//
// QML only renders the resulting state.
// ============================================================


const DBUS_NAME: &str = "org.freedesktop.Notifications";
const DBUS_PATH: &str = "/org/freedesktop/Notifications";


// ============================================================
// DATA
// ============================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationAction {
    pub key: String,
    pub label: String,
}


#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Notification {
    pub id: u32,

    pub app_name: String,
    pub app_icon: String,

    pub summary: String,
    pub body: String,

    pub actions: Vec<NotificationAction>,

    pub expire_timeout: i32,

    pub timestamp: u64,

    pub read: bool,
}


#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct NotificationState {
    pub notifications: Vec<Notification>,
    pub unread_count: usize,
}


// ============================================================
// STORAGE
// ============================================================

fn state_path() -> PathBuf {
    let home = env::var("HOME")
        .unwrap_or_else(|_| "/tmp".to_string());

    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("notifications.json")
}


fn now_timestamp() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_secs()
}


fn popup_timeout_ms(expire_timeout: i32) -> u64 {
    match expire_timeout {
        value if value > 0 => {
            // Do not let an app keep the Island occupied forever.
            (value as u64).min(5000)
        }

        _ => 5000,
    }
}

fn write_state(notifications: &[Notification]) {
    let path = state_path();

    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let unread_count = notifications
        .iter()
        .filter(|notification| !notification.read)
        .count();

    let state = NotificationState {
        notifications: notifications.to_vec(),
        unread_count,
    };

    if let Ok(json) = serde_json::to_string_pretty(&state) {
        let temporary = path.with_extension("tmp");

        if fs::write(&temporary, json).is_ok() {
            let _ = fs::rename(temporary, path);
        }
    }
}


fn load_state() -> Vec<Notification> {
    let path = state_path();

    let Ok(data) = fs::read_to_string(path) else {
        return Vec::new();
    };

    let Ok(state) = serde_json::from_str::<NotificationState>(&data) else {
        return Vec::new();
    };

    state.notifications
}


//Island helper

fn transient_path() -> PathBuf {
    let home = env::var("HOME")
        .unwrap_or_else(|_| "/tmp".to_string());

    PathBuf::from(home)
        .join(".cache")
        .join("nexa")
        .join("notification-event.json")
}


// ============================================================
// DO NOT DISTURB
// ============================================================



fn dnd_path() -> PathBuf {
    let home =
        env::var("HOME")
            .unwrap_or_else(
                |_| "/tmp".to_string()
            );

    PathBuf::from(home)
        .join(".config")
        .join("nexa")
        .join("config")
        .join("notifications.conf")
}


fn load_dnd() -> bool {
    let Ok(content) =
        fs::read_to_string(
            dnd_path()
        )
    else {
        return false;
    };


    for line in content.lines() {
        let Some(
            (key, value)
        ) = line.split_once('=')
        else {
            continue;
        };


        if key.trim() == "dnd" {
            return matches!(
                value.trim(),
                "true"
                    | "1"
                    | "on"
                    | "yes"
            );
        }
    }


    false
}


fn save_dnd(
    enabled: bool,
) -> Result<(), String> {
    let path =
        dnd_path();


    if let Some(parent) =
        path.parent()
    {
        fs::create_dir_all(
            parent
        )
        .map_err(
            |error|
                format!(
                    "Failed to create notification config directory: {error}"
                )
        )?;
    }


    fs::write(
        &path,
        format!(
            "dnd={enabled}\n"
        ),
    )
    .map_err(
        |error|
            format!(
                "Failed to save DND state: {error}"
            )
    )
}


fn print_dnd(
    enabled: bool,
) {
    println!(
        "{}",
        serde_json::json!({
            "enabled": enabled
        })
    );
}


pub fn dnd_info() {
    print_dnd(
        load_dnd()
    );
}


pub fn dnd_on() {
    match save_dnd(
        true
    ) {
        Ok(()) => {
            print_dnd(
                true
            );
        }

        Err(error) => {
            eprintln!(
                "{error}"
            );
        }
    }
}


pub fn dnd_off() {
    match save_dnd(
        false
    ) {
        Ok(()) => {
            print_dnd(
                false
            );
        }

        Err(error) => {
            eprintln!(
                "{error}"
            );
        }
    }
}


pub fn dnd_toggle() {
    let enabled =
        !load_dnd();


    match save_dnd(
        enabled
    ) {
        Ok(()) => {
            print_dnd(
                enabled
            );
        }

        Err(error) => {
            eprintln!(
                "{error}"
            );
        }
    }
}



fn write_transient_event(
    notification: &Notification,
) {
    let path = transient_path();

    if let Some(parent) = path.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let event = NotificationTransientEvent {
        // Timestamp + id gives QML a changing event value.
        serial:
            notification.timestamp
                .saturating_mul(1000)
                .saturating_add(notification.id as u64),

        id:
            notification.id,

        app_name:
            notification.app_name.clone(),

        app_icon:
            notification.app_icon.clone(),

        summary:
            notification.summary.clone(),

        body:
            notification.body.clone(),

        timestamp:
            notification.timestamp,

        timeout_ms:
            popup_timeout_ms(
                notification.expire_timeout
            ),
    };

    if let Ok(json) =
        serde_json::to_string_pretty(&event)
    {
        let temporary =
            path.with_extension("tmp");

        if fs::write(
            &temporary,
            json,
        )
        .is_ok()
        {
            let _ =
                fs::rename(
                    temporary,
                    path,
                );
        }
    }
}

// ============================================================
// ACTION PARSER
//
// Freedesktop actions arrive like:
//
// [
//   "default", "Open",
//   "reply",   "Reply"
// ]
//
// Convert those into structured Rust data.
// ============================================================

fn parse_actions(raw: Vec<String>) -> Vec<NotificationAction> {
    raw.chunks(2)
        .filter_map(|pair| {
            if pair.len() != 2 {
                return None;
            }

            Some(NotificationAction {
                key: pair[0].clone(),
                label: pair[1].clone(),
            })
        })
        .collect()
}


// ============================================================
// SERVER STATE
// ============================================================

#[derive(Clone)]
struct NotificationServer {
    notifications: Arc<Mutex<Vec<Notification>>>,
    next_id: Arc<AtomicU32>,
    latest_transient: Arc<Mutex<Option<u32>>>,
}


impl NotificationServer {
    fn new() -> Self {
        let notifications = load_state();

        let highest_id = notifications
            .iter()
            .map(|notification| notification.id)
            .max()
            .unwrap_or(0);

        Self {
            notifications: Arc::new(
                Mutex::new(notifications)
            ),

            next_id: Arc::new(
                AtomicU32::new(
                    highest_id.saturating_add(1)
                )
            ),

            latest_transient: Arc::new(
                Mutex::new(None)
            ),
        }
    }

    fn next_notification_id(&self) -> u32 {
        self.next_id.fetch_add(
            1,
            Ordering::Relaxed
        )
    }
}
// ============================================================
// ICON 
// ============================================================


fn icon_search_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();

    if let Ok(home) = env::var("HOME") {
        roots.push(
            PathBuf::from(&home)
                .join(".local/share/icons")
        );

        roots.push(
            PathBuf::from(&home)
                .join(".icons")
        );
    }

    roots.push(
        PathBuf::from("/usr/share/icons")
    );

    roots.push(
        PathBuf::from("/usr/share/pixmaps")
    );

    roots
}


fn desktop_search_roots() -> Vec<PathBuf> {
    let mut roots = Vec::new();

    if let Ok(home) = env::var("HOME") {
        roots.push(
            PathBuf::from(&home)
                .join(".local/share/applications")
        );
    }

    roots.push(
        PathBuf::from("/usr/share/applications")
    );

    roots
}


fn is_image_file(path: &Path) -> bool {
    let Some(ext) = path.extension() else {
        return false;
    };

    matches!(
        ext.to_string_lossy()
            .to_ascii_lowercase()
            .as_str(),
        "png" | "svg" | "jpg" | "jpeg" | "webp" | "xpm"
    )
}


fn find_icon_file(icon_name: &str) -> Option<String> {
    if icon_name.is_empty() {
        return None;
    }

    let direct = PathBuf::from(icon_name);

    if direct.is_absolute()
        && direct.exists()
        && is_image_file(&direct)
    {
        return Some(
            direct.to_string_lossy().to_string()
        );
    }


    let names = if Path::new(icon_name).extension().is_some() {
        vec![icon_name.to_string()]
    } else {
        vec![
            format!("{icon_name}.svg"),
            format!("{icon_name}.png"),
            format!("{icon_name}.xpm"),
            format!("{icon_name}.webp"),
        ]
    };


    for root in icon_search_roots() {
        if !root.exists() {
            continue;
        }

        for entry in walkdir::WalkDir::new(&root)
            .follow_links(true)
            .into_iter()
            .filter_map(Result::ok)
        {
            if !entry.file_type().is_file() {
                continue;
            }

            let filename =
                entry.file_name().to_string_lossy();

            if names.iter().any(|name| filename == name.as_str()) {
                return Some(
                    entry.path()
                        .to_string_lossy()
                        .to_string()
                );
            }
        }
    }

    None
}


fn desktop_icon_name(app_name: &str) -> Option<String> {
    if app_name.is_empty() {
        return None;
    }

    let wanted =
        app_name.to_ascii_lowercase();


    for root in desktop_search_roots() {
        if !root.exists() {
            continue;
        }

        for entry in walkdir::WalkDir::new(&root)
            .max_depth(2)
            .into_iter()
            .filter_map(Result::ok)
        {
            if !entry.file_type().is_file() {
                continue;
            }

            let path = entry.path();

            if path.extension()
                .and_then(|ext| ext.to_str())
                != Some("desktop")
            {
                continue;
            }


            let Ok(contents) =
                fs::read_to_string(path)
            else {
                continue;
            };


            let mut name = None;
            let mut icon = None;

            for line in contents.lines() {
                if name.is_none()
                    && line.starts_with("Name=")
                {
                    name = Some(
                        line.trim_start_matches("Name=")
                            .trim()
                            .to_string()
                    );
                }

                if icon.is_none()
                    && line.starts_with("Icon=")
                {
                    icon = Some(
                        line.trim_start_matches("Icon=")
                            .trim()
                            .to_string()
                    );
                }

                if name.is_some() && icon.is_some() {
                    break;
                }
            }


            let desktop_filename = path
                .file_stem()
                .and_then(|value| value.to_str())
                .unwrap_or("")
                .to_ascii_lowercase();


            let name_matches = name
                .as_ref()
                .map(|value| {
                    value.to_ascii_lowercase() == wanted
                })
                .unwrap_or(false);


            let filename_matches =
                desktop_filename == wanted
                || desktop_filename.contains(&wanted)
                || wanted.contains(&desktop_filename);


            if name_matches || filename_matches {
                if let Some(icon) = icon {
                    return Some(icon);
                }
            }
        }
    }

    None
}

fn resolve_app_icon(
    app_name: &str,
    app_icon: &str,
) -> String {

    if let Some(path) =
        find_icon_file(app_icon)
    {
        return path;
    }


    if let Some(icon_name) =
        desktop_icon_name(app_name)
    {
        if let Some(path) =
            find_icon_file(&icon_name)
        {
            return path;
        }
    }


    String::new()
}

// ============================================================
// FREEDESKTOP NOTIFICATION INTERFACE
// ============================================================

#[interface(name = "org.freedesktop.Notifications")]
impl NotificationServer {

    // ========================================================
    // NOTIFY
    // ========================================================

    async fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        _hints: HashMap<String, OwnedValue>,
        expire_timeout: i32,
    ) -> u32 {

        let resolved_icon =
        resolve_app_icon(
            &app_name,
            &app_icon,
        );

        let mut notifications = match self.notifications.lock() {
            Ok(value) => value,
            Err(_) => return 0,
        };


        // ----------------------------------------------------
        // REPLACE EXISTING NOTIFICATION
        // ----------------------------------------------------

        if replaces_id != 0 {
            if let Some(existing) = notifications
                .iter_mut()
                .find(|notification| notification.id == replaces_id)
            {
                existing.app_name = app_name;
                existing.app_icon = resolved_icon.clone();
                existing.summary = summary;
                existing.body = body;

                existing.actions = parse_actions(actions);

                existing.expire_timeout = expire_timeout;
                existing.timestamp = now_timestamp();

                existing.read = false;

                let id = existing.id;

                write_state(&notifications);

                return id;
            }
        }


        // ----------------------------------------------------
        // NEW NOTIFICATION
        // ----------------------------------------------------

        let id = self.next_notification_id();

        let notification = Notification {
            id,

            app_name,
            app_icon: resolved_icon,

            summary,
            body,

            actions: parse_actions(actions),

            expire_timeout,

            timestamp: now_timestamp(),

            read: false,
        };


        // Send the exact new notification to the transient surface
        // before moving it into history.
        // ----------------------------------------------------
        // TRANSIENT / DND
        //
        // DND only suppresses the transient Island event.
        // Notification history is still stored normally.
        // ----------------------------------------------------

        if !load_dnd() {
            write_transient_event(
                &notification
            );
        }


        notifications.insert(
            0,
            notification
        );


        if let Ok(mut latest) =
            self.latest_transient.lock()
        {
            *latest = Some(id);
        }

        
        // ----------------------------------------------------
        // HISTORY LIMIT
        // ----------------------------------------------------

        const MAX_HISTORY: usize = 100;

        if notifications.len() > MAX_HISTORY {
            notifications.truncate(MAX_HISTORY);
        }


        write_state(&notifications);

        id
    }


    // ========================================================
    // CLOSE NOTIFICATION
    // ========================================================

    async fn close_notification(
        &self,
        id: u32,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) {
        let removed = {
            if let Ok(mut notifications) = self.notifications.lock() {

                let before = notifications.len();

                notifications.retain(
                    |notification| notification.id != id
                );

                let removed = notifications.len() != before;

                if removed {
                    write_state(&notifications);
                }

                removed
            } else {
                false
            }
        };

        if removed {
            let _ = Self::notification_closed(
                &emitter,
                id,
                3,
            )
            .await;
        }
    }


    // ========================================================
    // INVOKE ACTION
    // ========================================================

    async fn invoke_action(
        &self,
        id: u32,
        action_key: String,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) -> bool {

        let valid = {
            match self.notifications.lock() {
                Ok(notifications) => {
                    notifications.iter().any(|notification| {
                        notification.id == id
                            && notification.actions.iter().any(|action| {
                                action.key == action_key
                            })
                    })
                }

                Err(_) => false,
            }
        };


        if !valid {
            return false;
        }


        if Self::action_invoked(
            &emitter,
            id,
            action_key,
        )
        .await
        .is_err()
        {
            return false;
        }


        true
    }


    // ========================================================
    // CAPABILITIES
    // ========================================================

    fn get_capabilities(&self) -> Vec<String> {
        vec![
            "body".to_string(),
            "actions".to_string(),
            "persistence".to_string(),
        ]
    }


    // ========================================================
    // SERVER INFORMATION
    // ========================================================

    fn get_server_information(
        &self
    ) -> (String, String, String, String) {
        (
            "NEXA".to_string(),
            "NEXA".to_string(),
            "0.1.0".to_string(),
            "1.2".to_string(),
        )
    }


    // ========================================================
    // SIGNALS
    //
    // THESE MUST STAY INSIDE THE #[interface] IMPL
    // ========================================================

    #[zbus(signal)]
    async fn notification_closed(
        emitter: &SignalEmitter<'_>,
        id: u32,
        reason: u32,
    ) -> zbus::Result<()>;


    #[zbus(signal)]
    async fn action_invoked(
        emitter: &SignalEmitter<'_>,
        id: u32,
        action_key: String,
    ) -> zbus::Result<()>;



    async fn mark_read(
        &self,
        id: u32,
    ) -> bool {
        let mut changed = false;

        if let Ok(mut notifications) = self.notifications.lock() {
            if let Some(notification) = notifications
                .iter_mut()
                .find(|notification| notification.id == id)
            {
                if !notification.read {
                    notification.read = true;
                    changed = true;
                }
            }

            if changed {
                write_state(&notifications);
            }
        }

        changed
    }


    async fn mark_all_read(
        &self,
    ) -> u32 {
        let mut changed_count = 0;

        if let Ok(mut notifications) = self.notifications.lock() {
            for notification in notifications.iter_mut() {
                if !notification.read {
                    notification.read = true;
                    changed_count += 1;
                }
            }

            if changed_count > 0 {
                write_state(&notifications);
            }
        }

        changed_count
    }
}


// ============================================================
// DAEMON
// ============================================================

pub async fn run_daemon() -> zbus::Result<()> {

    let server = NotificationServer::new();


    let connection = Connection::session().await?;


    connection
        .request_name(DBUS_NAME)
        .await?;


    connection
        .object_server()
        .at(DBUS_PATH, server)
        .await?;


    println!(
        "NEXA notification server running on {}",
        DBUS_NAME
    );


    // Keep daemon alive.
    futures_lite::future::pending::<()>().await;

    Ok(())
}


// ============================================================
// CLI — LIST
// ============================================================

pub fn list() {
    let notifications = load_state();

    let unread_count = notifications
        .iter()
        .filter(|notification| !notification.read)
        .count();

    let state = NotificationState {
        notifications,
        unread_count,
    };

    match serde_json::to_string(&state) {
        Ok(json) => println!("{json}"),

        Err(error) => {
            eprintln!(
                "{{\"success\":false,\"error\":\"{}\"}}",
                error
            );
        }
    }
}


// ============================================================
// CLI — DISMISS
// ============================================================

pub async fn dismiss(id: u32) -> zbus::Result<()> {
    let connection = Connection::session().await?;

    let proxy = zbus::Proxy::new(
        &connection,
        DBUS_NAME,
        DBUS_PATH,
        DBUS_NAME,
    )
    .await?;

    // First try the live daemon.
    let result: zbus::Result<()> = proxy
        .call(
            "CloseNotification",
            &(id),
        )
        .await;

    if result.is_ok() {
        println!(
            "{{\"success\":true,\"id\":{},\"source\":\"daemon\"}}",
            id
        );

        return Ok(());
    }

    // --------------------------------------------------------
    // FALLBACK
    //
    // If the notification daemon is not currently available,
    // remove the item directly from persistent history.
    // --------------------------------------------------------

    let mut notifications = load_state();

    let before = notifications.len();

    notifications.retain(
        |notification| notification.id != id
    );

    let removed =
        notifications.len() != before;

    if removed {
        write_state(&notifications);
    }

    println!(
        "{{\"success\":{},\"id\":{},\"source\":\"storage\"}}",
        removed,
        id
    );

    Ok(())
}


// ============================================================
// CLI — CLEAR
// ============================================================

pub async fn clear() -> zbus::Result<()> {
    let notifications = load_state();

    if notifications.is_empty() {
        println!(
            "{{\"success\":true,\"cleared\":0}}"
        );

        return Ok(());
    }

    let total =
        notifications.len();

    let connection =
        Connection::session().await?;

    let proxy = zbus::Proxy::new(
        &connection,
        DBUS_NAME,
        DBUS_PATH,
        DBUS_NAME,
    )
    .await?;

    let ids: Vec<u32> =
        notifications
            .iter()
            .map(|notification| notification.id)
            .collect();

    let mut cleared = 0;


    // --------------------------------------------------------
    // FIRST TRY THE LIVE DAEMON
    // --------------------------------------------------------

    for id in ids {
        let result: zbus::Result<()> =
            proxy
                .call(
                    "CloseNotification",
                    &(id),
                )
                .await;

        if result.is_ok() {
            cleared += 1;
        }
    }


    // --------------------------------------------------------
    // FALLBACK
    //
    // If daemon calls did not remove everything, force the
    // persistent history to empty.
    //
    // This prevents stale notification cards remaining in
    // notifications.json.
    // --------------------------------------------------------

    if cleared < total {
        write_state(&[]);

        println!(
            "{{\"success\":true,\"cleared\":{},\"source\":\"storage\"}}",
            total
        );

        return Ok(());
    }


    println!(
        "{{\"success\":true,\"cleared\":{},\"source\":\"daemon\"}}",
        cleared
    );

    Ok(())
}

// ============================================================
// ACTION
// ============================================================

pub async fn action(
    id: u32,
    action_key: String,
) -> zbus::Result<()> {
    let connection = Connection::session().await?;

    let proxy = zbus::Proxy::new(
        &connection,
        DBUS_NAME,
        DBUS_PATH,
        DBUS_NAME,
    )
    .await?;

    let success: bool = proxy
        .call(
            "InvokeAction",
            &(id, action_key.clone()),
        )
        .await?;

    println!(
        "{{\"success\":{},\"id\":{},\"action\":\"{}\"}}",
        success,
        id,
        action_key
    );

    Ok(())
}

// ============================================================
// READ
// ============================================================



pub async fn read(id: u32) -> zbus::Result<()> {
    let connection = Connection::session().await?;

    let proxy = zbus::Proxy::new(
        &connection,
        DBUS_NAME,
        DBUS_PATH,
        DBUS_NAME,
    )
    .await?;

    let changed: bool = proxy
        .call(
            "MarkRead",
            &(id),
        )
        .await?;

    println!(
        "{{\"success\":{},\"id\":{}}}",
        changed,
        id
    );

    Ok(())
}

// ============================================================
// CLI — MARK ALL READ
// ============================================================

pub async fn read_all() -> zbus::Result<()> {
    let connection = Connection::session().await?;

    let proxy = zbus::Proxy::new(
        &connection,
        DBUS_NAME,
        DBUS_PATH,
        DBUS_NAME,
    )
    .await?;

    let changed: u32 = proxy
        .call(
            "MarkAllRead",
            &(),
        )
        .await?;

    println!(
        "{{\"success\":true,\"changed\":{}}}",
        changed
    );

    Ok(())
}
