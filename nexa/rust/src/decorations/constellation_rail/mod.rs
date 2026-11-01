pub mod config;
pub mod state;

pub fn handle_cli(args: &[String]) -> Result<(), String> {
    if args.is_empty() || args[0] == "state" {
        let s = state::get_state();
        let json = serde_json::to_string(&s)
            .map_err(|e| format!("Failed to serialize constellation state: {e}"))?;
        println!("{json}");
        return Ok(());
    }

    match args[0].as_str() {
        "config" | "get" => {
            let cfg = config::load_config();
            let json = serde_json::to_string_pretty(&cfg)
                .map_err(|e| format!("Failed to serialize constellation config: {e}"))?;
            println!("{json}");
            Ok(())
        }
        "toggle" => {
            let mut cfg = config::load_config();
            cfg.enabled = !cfg.enabled;
            config::save_config(&cfg)?;
            println!("{{\"enabled\":{}}}", cfg.enabled);
            Ok(())
        }
        "set" => {
            let mut cfg = config::load_config();
            let mut i = 1;
            while i < args.len() {
                match args[i].as_str() {
                    "--enabled" => {
                        if i + 1 < args.len() {
                            cfg.enabled = args[i + 1] == "true" || args[i + 1] == "1";
                            i += 1;
                        }
                    }
                    "--style" => {
                        if i + 1 < args.len() {
                            cfg.style = args[i + 1].clone();
                            i += 1;
                        }
                    }
                    "--mode" => {
                        if i + 1 < args.len() {
                            cfg.mode = args[i + 1].clone();
                            i += 1;
                        }
                    }
                    "--direction" => {
                        if i + 1 < args.len() {
                            cfg.direction = args[i + 1].clone();
                            i += 1;
                        }
                    }
                    "--speed" => {
                        if i + 1 < args.len() {
                            if let Ok(v) = args[i + 1].parse::<f64>() {
                                cfg.speed = v;
                            }
                            i += 1;
                        }
                    }
                    "--glow" => {
                        if i + 1 < args.len() {
                            if let Ok(v) = args[i + 1].parse::<f64>() {
                                cfg.glow_intensity = v;
                            }
                            i += 1;
                        }
                    }
                    "--count" => {
                        if i + 1 < args.len() {
                            if let Ok(v) = args[i + 1].parse::<usize>() {
                                cfg.particle_count = v;
                            }
                            i += 1;
                        }
                    }
                    "--opacity" => {
                        if i + 1 < args.len() {
                            if let Ok(v) = args[i + 1].parse::<f64>() {
                                cfg.line_opacity = v;
                            }
                            i += 1;
                        }
                    }
                    _ => {}
                }
                i += 1;
            }
            config::save_config(&cfg)?;
            println!("{{\"success\":true}}");
            Ok(())
        }
        _ => Err(format!("Unknown constellation command: {}", args[0])),
    }
}
