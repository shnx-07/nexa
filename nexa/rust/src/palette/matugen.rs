use std::{path::Path, process::Command};
use serde_json::Value;
use super::types::PaletteColors;

pub fn extract_palette(path: &Path) -> PaletteColors {
    let mut colors = PaletteColors::default();

    let output = Command::new("matugen")
        .arg("image")
        .arg(path)
        .arg("--source-color-index")
        .arg("0")
        .arg("--dry-run")
        .arg("--json")
        .arg("hex")
        .output();

    let Ok(output) = output else {
        return colors;
    };

    if !output.status.success() {
        return colors;
    }

    let Ok(text) = std::str::from_utf8(&output.stdout) else {
        return colors;
    };

    let Ok(json): Result<Value, _> = serde_json::from_str(text) else {
        return colors;
    };

    let Some(c) = json.get("colors") else {
        return colors;
    };

    if let Some(val) = extract_color_str(c, "primary") {
        colors.primary = val;
    }
    if let Some(val) = extract_color_str(c, "secondary") {
        colors.secondary = val;
    }
    if let Some(val) = extract_color_str(c, "tertiary") {
        colors.tertiary = val;
    }
    if let Some(val) = extract_color_str(c, "surface_container") {
        colors.container = val;
    }
    if let Some(val) = extract_color_str(c, "surface") {
        colors.surface = val;
    }

    colors
}

fn extract_color_str(colors: &Value, name: &str) -> Option<String> {
    let role = colors.get(name)?;
    
    // Check role.default.color
    if let Some(c) = role.get("default").and_then(|d| d.get("color")).and_then(|v| v.as_str()) {
        return Some(c.to_uppercase());
    }

    // Check role.dark.color
    if let Some(c) = role.get("dark").and_then(|d| d.get("color")).and_then(|v| v.as_str()) {
        return Some(c.to_uppercase());
    }

    // Direct string
    if let Some(c) = role.as_str() {
        return Some(c.to_uppercase());
    }

    None
}
