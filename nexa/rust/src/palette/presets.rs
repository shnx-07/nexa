use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    env, fs,
    path::PathBuf,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PresetEntry {
    pub id: String,
    pub category: String,
    pub name: String,
    pub variants: Vec<String>,
    pub previews: HashMap<String, Vec<String>>,
}

pub fn preset_root() -> PathBuf {
    let home = env::var("HOME").unwrap_or_else(|_| String::from("."));
    PathBuf::from(home).join(".config/matugen/presets")
}

pub fn list_presets() -> Vec<PresetEntry> {
    let root = preset_root();
    let mut entries: HashMap<String, PresetEntry> = HashMap::new();

    if !root.exists() {
        return Vec::new();
    }

    for entry in walkdir::WalkDir::new(&root).into_iter().flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("json") {
            continue;
        }

        let Ok(rel) = path.strip_prefix(&root) else {
            continue;
        };

        let Ok(text) = fs::read_to_string(path) else {
            continue;
        };
        let Ok(data): Result<serde_json::Value, _> = serde_json::from_str(&text) else {
            continue;
        };

        let meta = data.get("meta").and_then(|m| m.as_object());
        let stem = path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_lowercase();
        let is_paired = (stem == "dark" || stem == "light") && rel.components().count() >= 3;

        let (preset_id, category, name, variant, preview_key) = if is_paired {
            let parent_rel = rel.parent().unwrap_or(rel);
            let p_id = parent_rel.to_string_lossy().to_string();
            let cat = meta
                .and_then(|m| m.get("category"))
                .and_then(|v| v.as_str())
                .map(String::from)
                .unwrap_or_else(|| {
                    rel.components()
                        .next()
                        .map(|c| c.as_os_str().to_string_lossy().to_string())
                        .unwrap_or_default()
                });
            let n = meta
                .and_then(|m| m.get("name"))
                .and_then(|v| v.as_str())
                .map(String::from)
                .unwrap_or_else(|| {
                    parent_rel
                        .file_name()
                        .map(|f| f.to_string_lossy().to_string())
                        .unwrap_or_default()
                });
            let v = stem.clone();
            (p_id, cat, n, Some(v.clone()), v)
        } else {
            let mut p_id = rel.to_string_lossy().to_string();
            if p_id.ends_with(".json") {
                p_id.truncate(p_id.len() - 5);
            }
            let cat = meta
                .and_then(|m| m.get("category"))
                .and_then(|v| v.as_str())
                .map(String::from)
                .unwrap_or_else(|| {
                    if rel.components().count() > 1 {
                        rel.components()
                            .next()
                            .map(|c| c.as_os_str().to_string_lossy().to_string())
                            .unwrap_or_else(|| "uncategorized".into())
                    } else {
                        "uncategorized".into()
                    }
                });
            let n = meta
                .and_then(|m| m.get("name"))
                .and_then(|v| v.as_str())
                .map(String::from)
                .unwrap_or_else(|| {
                    path.file_stem()
                        .map(|s| s.to_string_lossy().to_string())
                        .unwrap_or_default()
                });
            let v = meta
                .and_then(|m| m.get("variant"))
                .and_then(|x| x.as_str())
                .map(|s| s.to_lowercase());
            let pk = if let Some(ref vr) = v {
                if vr == "dark" || vr == "light" {
                    vr.clone()
                } else {
                    "default".into()
                }
            } else {
                "default".into()
            };
            (p_id, cat, n, v, pk)
        };

        let item = entries.entry(preset_id.clone()).or_insert_with(|| PresetEntry {
            id: preset_id,
            category,
            name,
            variants: Vec::new(),
            previews: HashMap::new(),
        });

        if let Some(vr) = variant {
            if !item.variants.contains(&vr) {
                item.variants.push(vr);
            }
        }

        // Preview colors: primary, secondary, tertiary
        if let Some(colors) = data.get("colors").and_then(|c| c.as_object()) {
            let p = colors.get("primary").and_then(|v| v.as_str());
            let s = colors.get("secondary").and_then(|v| v.as_str());
            let t = colors.get("tertiary").and_then(|v| v.as_str());
            if let (Some(p), Some(s), Some(t)) = (p, s, t) {
                item.previews
                    .insert(preview_key, vec![p.to_string(), s.to_string(), t.to_string()]);
            }
        }
    }

    let mut result: Vec<PresetEntry> = entries.into_values().collect();

    for item in &mut result {
        item.variants.sort_by(|a, b| {
            let a_dark = a == "dark";
            let b_dark = b == "dark";
            let a_light = a == "light";
            let b_light = b == "light";
            (!a_dark, !a_light, a).cmp(&(!b_dark, !b_light, b))
        });
    }

    result.sort_by(|a, b| {
        a.category
            .to_lowercase()
            .cmp(&b.category.to_lowercase())
            .then_with(|| a.name.to_lowercase().cmp(&b.name.to_lowercase()))
    });

    result
}

pub fn print_presets_json() {
    let list = list_presets();
    if let Ok(json) = serde_json::to_string_pretty(&list) {
        println!("{json}");
    }
}

pub fn resolve_preset(requested: &str, mode: &str) -> Result<PathBuf, String> {
    let root = preset_root();
    let norm_req = norm(requested);
    let mode_lower = mode.to_lowercase();
    let mut matches = Vec::new();

    for entry in walkdir::WalkDir::new(&root).into_iter().flatten() {
        let path = entry.path();
        if path.extension().and_then(|e| e.to_str()) != Some("json") {
            continue;
        }
        let Ok(rel) = path.strip_prefix(&root) else {
            continue;
        };

        let stem = path
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("")
            .to_lowercase();
        let is_paired = (stem == "dark" || stem == "light") && rel.components().count() >= 3;

        let rel_no_ext = rel.with_extension("");
        if norm(&rel_no_ext.to_string_lossy()) == norm_req {
            return Ok(path.to_path_buf());
        }

        if is_paired {
            let parent_rel = rel.parent().unwrap_or(rel);
            if norm(&parent_rel.to_string_lossy()) == norm_req {
                if stem == mode_lower {
                    return Ok(path.to_path_buf());
                }
                matches.push(path.to_path_buf());
            }
        }

        if let Ok(text) = fs::read_to_string(path) {
            if let Ok(data) = serde_json::from_str::<serde_json::Value>(&text) {
                if let Some(meta) = data.get("meta").and_then(|m| m.as_object()) {
                    let id = meta.get("id").and_then(|v| v.as_str()).unwrap_or("");
                    let name = meta.get("name").and_then(|v| v.as_str()).unwrap_or("");
                    if norm(id) == norm_req || norm(name) == norm_req {
                        if is_paired && stem != mode_lower {
                            continue;
                        }
                        matches.push(path.to_path_buf());
                    }
                }
            }
        }
    }

    if matches.len() == 1 {
        return Ok(matches[0].clone());
    }

    if matches.is_empty() {
        let direct = root.join(format!("{requested}.json"));
        if direct.exists() {
            return Ok(direct);
        }
        let direct_variant = root
            .join(requested)
            .join(if mode_lower == "light" { "Light.json" } else { "Dark.json" });
        if direct_variant.exists() {
            return Ok(direct_variant);
        }
        Err(format!("Preset not found: {requested}"))
    } else {
        Ok(matches[0].clone())
    }
}

fn norm(s: &str) -> String {
    s.chars()
        .filter(|c| c.is_alphanumeric())
        .flat_map(|c| c.to_lowercase())
        .collect()
}
