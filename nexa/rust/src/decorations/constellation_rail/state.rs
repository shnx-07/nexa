use super::config;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NodeState {
    pub id: usize,
    pub active: bool,
    pub occupied: bool,
    pub pos: f64,        // Normalized 0.0 to 1.0 position
    pub brightness: f64, // 0.0 to 1.0
    pub halo_scale: f64, // 0.0 to 1.0
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConstellationState {
    pub enabled: bool,
    pub mode: String,
    pub direction: String,
    pub speed: f64,
    pub is_playing: bool,
    pub nodes: Vec<NodeState>,
}

#[derive(Debug, Deserialize)]
struct HyprWorkspace {
    id: i32,
    windows: i32,
}

#[derive(Debug, Deserialize)]
struct HyprActiveWorkspace {
    id: i32,
}

pub fn get_state() -> ConstellationState {
    let cfg = config::load_config();
    let count = cfg.particle_count.clamp(3, 20);

    // 1. Check media playback sync
    let is_playing = crate::media_tools::media::get_current_state()
        .map(|m| m.status.eq_ignore_ascii_case("playing"))
        .unwrap_or(false);

    // 2. Build nodes according to mode
    let nodes = match cfg.mode.as_str() {
        "workspaces" => build_workspace_nodes(count),
        _ => build_default_nodes(count),
    };

    ConstellationState {
        enabled: cfg.enabled,
        mode: cfg.mode,
        direction: cfg.direction,
        speed: cfg.speed,
        is_playing,
        nodes,
    }
}

fn build_workspace_nodes(count: usize) -> Vec<NodeState> {
    // Query Hyprland active workspace & workspaces list
    let active_id = crate::hyprland::query_json::<HyprActiveWorkspace>("activeworkspace")
        .map(|w| w.id)
        .unwrap_or(1);

    let workspaces = crate::hyprland::query_json::<Vec<HyprWorkspace>>("workspaces")
        .unwrap_or_default();

    let step = 1.0 / (count as f64 + 1.0);

    (1..=count)
        .map(|id| {
            let active = id as i32 == active_id;
            let occupied = workspaces
                .iter()
                .any(|w| w.id == id as i32 && w.windows > 0);

            let pos = step * id as f64;

            let (brightness, halo_scale) = if active {
                (1.0, 1.0)
            } else if occupied {
                (0.65, 0.45)
            } else {
                (0.20, 0.0)
            };

            NodeState {
                id,
                active,
                occupied,
                pos,
                brightness,
                halo_scale,
            }
        })
        .collect()
}

fn build_default_nodes(count: usize) -> Vec<NodeState> {
    let step = 1.0 / (count as f64 + 1.0);
    (1..=count)
        .map(|id| {
            let pos = step * id as f64;
            NodeState {
                id,
                active: false,
                occupied: false,
                pos,
                brightness: 0.5,
                halo_scale: 0.3,
            }
        })
        .collect()
}
