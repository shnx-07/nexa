pub mod media;
pub mod recorder;
pub mod screenshot;
pub mod snipping;
pub mod visualizer;

// Re-exported from dedicated crate::wallpaper module for backward compatibility
pub use crate::wallpaper;
pub use crate::wallpaper::slideshow;
pub use crate::wallpaper::transition;
