use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaletteColors {
    pub primary: String,
    pub secondary: String,
    pub tertiary: String,
    pub container: String,
    pub surface: String,
}

impl Default for PaletteColors {
    fn default() -> Self {
        Self {
            primary: String::from("#81D3DE"),
            secondary: String::from("#B1CBCF"),
            tertiary: String::from("#B8C6EA"),
            container: String::from("#1A2121"),
            surface: String::from("#0E1415"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WallpaperInfo {
    pub path: String,
    pub format: String,
    pub width: u32,
    pub height: u32,
    pub size: String,
    pub palette: PaletteColors,
}
