use serde::{Deserialize, Serialize};

// =========================================================================
// [EXTENSION POINT]: ADD NEW WALLPAPER VIEW SHAPES & LAYOUTS HERE
// To add a new view shape mode (e.g. Hexagonal, Polar, Masonry):
// 1. Add the enum variant in `ViewShapeMode`
// 2. Implement the shape calculation function below
// =========================================================================
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ViewShapeMode {
    CoverflowSlanted,  // Default 3D slanted carousel
    GalleryGrid,       // Default slideshow 5-column grid
    // [EXTENSION HOOKS FOR FUTURE SHAPES]:
    // HexagonalCards,
    // PolarCylinder,
    // MasonryFlow,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CarouselMetrics {
    pub card_width: f32,
    pub card_height: f32,
    pub selected_width: f32,
    pub selected_height: f32,
    pub side_width: f32,
    pub item_spacing: f32,
    pub skew_factor: f32,
    pub media_center_offset: f32,
    pub media_width_padding: f32,
    pub media_height_padding: f32,
    pub aura_margin: f32,
    pub aura_blur: f32,
    pub aura_opacity: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GridMetrics {
    pub columns: usize,
    pub cell_height_ratio: f32,
    pub padding: f32,
    pub spacing: f32,
    pub corner_radius: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LayoutComputationPayload {
    pub mode: ViewShapeMode,
    pub screen_width: f32,
    pub screen_height: f32,
    pub carousel: CarouselMetrics,
    pub grid: GridMetrics,
}

pub fn compute_layout(screen_width: f32, screen_height: f32, mode: ViewShapeMode) -> LayoutComputationPayload {
    let w = if screen_width > 100.0 { screen_width } else { 1920.0 };
    let h = if screen_height > 100.0 { screen_height } else { 1080.0 };

    // Pixel-perfect metrics matching Nexa 3D slanted coverflow
    let card_width = 400.0f32;
    let card_height = 420.0f32;
    let selected_width = card_width * 1.5;   // 600.0
    let side_width = card_width * 0.5;       // 200.0
    let selected_height = card_height + 30.0; // 450.0
    let item_spacing = 10.0f32;
    let skew_factor = -0.35f32;

    let carousel = CarouselMetrics {
        card_width,
        card_height,
        selected_width,
        selected_height,
        side_width,
        item_spacing,
        skew_factor,
        media_center_offset: 0.32,
        media_width_padding: 100.0,
        media_height_padding: 20.0,
        aura_margin: -14.0,
        aura_blur: 32.0,
        aura_opacity: 0.65,
    };

    let grid = GridMetrics {
        columns: 5,
        cell_height_ratio: 9.0 / 16.0,
        padding: 24.0,
        spacing: 16.0,
        corner_radius: 14.0,
    };

    LayoutComputationPayload {
        mode,
        screen_width: w,
        screen_height: h,
        carousel,
        grid,
    }
}

pub fn print_layout_json(w: f32, h: f32, mode: &str) {
    let shape_mode = match mode.to_lowercase().as_str() {
        "grid" | "gallery" => ViewShapeMode::GalleryGrid,
        _ => ViewShapeMode::CoverflowSlanted,
    };

    let payload = compute_layout(w, h, shape_mode);
    if let Ok(json) = serde_json::to_string(&payload) {
        println!("{json}");
    } else {
        println!("{{}}");
    }
}
