pub mod core;
pub mod desktop;
pub mod display;
pub mod hardware;
pub mod hyprland;
pub mod media_tools;
pub mod palette;
pub mod services;
pub mod decorations;
pub mod wallpaper;

// Re-exports so internal code and CLI commands continue to work seamlessly
pub use core::{state, system};
pub use desktop::{island, lock, power, shelf, workspace};
pub use hardware::{audio, battery, brightness, network, screenFilter, screenTemp, sound};
pub use media_tools::{media, recorder, screenshot, snipping};
pub use wallpaper::slideshow;
pub use services::{
    appLauncher, clipboard, notifications, search, weather,
};

use std::env;

fn print_usage() {
    eprintln!(
        "Usage:
  nexad wallpaper list | search <query> | refresh | lock-set <path> | lock-info | apply <path> [monitor] | slideshow [status|next|set]
  nexad search refresh | query <query> | open <id>
  nexad workspace info | switch <1-10> | focus <address> | special <name>
  nexad command run <command> | query <query>
  nexad island search | command
  nexad shelf list | add <path>... | remove <id> | clear | copy-all | copy-item <id> | toggle | open | close
  nexad network wifi info | scan | refresh | on | off | connect <ssid> [password] | disconnect | forget <ssid>
  nexad network bluetooth info | on | off | scan on|off | pair <addr> | connect <addr> | disconnect <addr> | forget <addr>
  nexad appLauncher list | search <query> | launch <id> | refresh
  nexad screenshot capture
  nexad snipping capture
  nexad recorder start | pause | resume | stop | toggle | status
  nexad clipboard list | search <query> | copy <id> | pin <id> | unpin <id> | delete <id> | get <id> | clear
  nexad screenTemp info | enable | disable | toggle | mode <manual|wallpaper|night> | set <k> | apply | reset
  nexad notifications daemon | list | dismiss <id> | clear | read <id> | read-all | action <id> <key> | dnd <info|on|off|toggle>
  nexad power lock | suspend | logout | reboot | shutdown
  nexad lock auth | status
  nexad audio info | set <0-100> | mute | unmute | toggle-mute
  nexad brightness info | set <1-100> | up [amount] | down [amount]
  nexad system airplane info|on|off|toggle | vpn info|connect|disconnect|toggle
  nexad screenFilter info | set <filter> | off | apply
  nexad weather info | refresh | set <location>
  nexad media matugen <art_source> | fetch <title> <artist> | status | info | watch | toggle | next | prev
  nexad palette media <art_source> | info <path>
  nexad state restore | save
  nexad display [info|daemon|auto|cycle|mode|enable|disable|toggle|scale|res|rotate|mirror|primary|save|profiles] ..."
    );
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        print_usage();
        return;
    }

    match args[1].as_str() {
        "visualizer" | "cava" => {
            crate::media_tools::visualizer::handle_cli(&args[2..]);
        }
        "decoration" | "decorations" => {
            decorations::dispatch(&args[2..]);
        }
        "wallpaper" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "list" | "list-json" => {
                    let mut filter = None;
                    let mut dir = None;
                    let mut as_json = args[2] == "list-json";

                    for arg in &args[3..] {
                        if arg == "--json" {
                            as_json = true;
                        } else if matches!(arg.to_lowercase().as_str(), "all" | "image" | "gif" | "video") {
                            filter = Some(arg.as_str());
                        } else if !arg.starts_with("--") {
                            dir = Some(arg.as_str());
                        }
                    }

                    if as_json {
                        wallpaper::print_list_json(filter, dir);
                    } else {
                        wallpaper::print_list(dir);
                    }
                }
                "layout" => {
                    let mut width = 1920.0f32;
                    let mut height = 1080.0f32;
                    let mut mode = "carousel";
                    let mut i = 3;
                    while i < args.len() {
                        match args[i].as_str() {
                            "--width" | "-w" if i + 1 < args.len() => {
                                width = args[i + 1].parse().unwrap_or(1920.0);
                                i += 1;
                            }
                            "--height" | "-h" if i + 1 < args.len() => {
                                height = args[i + 1].parse().unwrap_or(1080.0);
                                i += 1;
                            }
                            "--mode" | "-m" if i + 1 < args.len() => {
                                mode = args[i + 1].as_str();
                                i += 1;
                            }
                            _ => {}
                        }
                        i += 1;
                    }
                    wallpaper::print_layout_json(width, height, mode);
                }
                "preview" => {
                    if args.len() < 4 {
                        eprintln!("Missing wallpaper path");
                        return;
                    }
                    let p = std::path::Path::new(&args[3]);
                    let thumb = wallpaper::preview::PreviewEngine::get_or_render_thumbnail(p);
                    println!("{}", thumb.display());
                }
                "restore" => {
                    if let Err(e) = wallpaper::restore_desktop() {
                        eprintln!("{e}");
                    }
                }
                "thumbs" | "slideshow-thumbs" => {
                    if let Err(e) = wallpaper::generate_slideshow_thumbs() {
                        eprintln!("{e}");
                    }
                }
                "info" => {
                    if args.len() < 4 {
                        eprintln!("Missing wallpaper path");
                        return;
                    }
                    palette::print_info(&args[3]);
                }
                "search" => {
                    if args.len() < 4 {
                        eprintln!("Missing search query");
                        return;
                    }
                    let mut as_json = false;
                    let mut query_parts = Vec::new();
                    for arg in &args[3..] {
                        if arg == "--json" {
                            as_json = true;
                        } else {
                            query_parts.push(arg.as_str());
                        }
                    }
                    let query = query_parts.join(" ");
                    if as_json {
                        wallpaper::print_search_json(&query);
                    } else {
                        wallpaper::print_search(&query);
                    }
                }
                "lock-set" => {
                    if args.len() < 4 {
                        eprintln!("Missing lock wallpaper path");
                        return;
                    }
                    if let Err(e) = wallpaper::set_lock(&args[3..].join(" ")) {
                        eprintln!("{e}");
                    }
                }
                "lock-info" => {
                    if let Err(e) = wallpaper::print_lock_info() {
                        eprintln!("{e}");
                    }
                }
                "apply" | "set" => {
                    if args.len() < 4 {
                        eprintln!("Missing wallpaper path");
                        return;
                    }
                    let path = &args[3];
                    let mut monitor = None;
                    let mut restore = false;
                    let mut no_theme = false;
                    let mut target = "Background";

                    let mut i = 4;
                    while i < args.len() {
                        match args[i].as_str() {
                            "--restore" => restore = true,
                            "--no-theme" => no_theme = true,
                            "--target" => {
                                if i + 1 < args.len() {
                                    target = &args[i + 1];
                                    i += 1;
                                }
                            }
                            m if !m.starts_with("--") => monitor = Some(m),
                            _ => {}
                        }
                        i += 1;
                    }

                    if target == "Background" {
                        if let Err(e) = wallpaper::apply_desktop(path, monitor, restore, no_theme) {
                            eprintln!("{e}");
                        }
                    } else if let Err(e) = wallpaper::apply_target(path, target, monitor) {
                        eprintln!("{e}");
                    }
                }
                "transition-args" => {
                    let engine = crate::media_tools::transition::TransitionEngine::new();
                    let effect = if let Some(name) = args.get(3) {
                        let nanos = std::time::SystemTime::now()
                            .duration_since(std::time::UNIX_EPOCH)
                            .map(|d| d.subsec_nanos() as usize)
                            .unwrap_or(0);
                        engine.build_effect(name, nanos)
                    } else {
                        engine.random_effect()
                    };
                    println!("{}", effect.args.join(" "));
                }
                "refresh" => wallpaper::refresh(),
                "slideshow" => {
                    if args.len() < 4 {
                        slideshow::print_status();
                        return;
                    }
                    match args[3].as_str() {
                        "daemon" | "watch" => {
                            slideshow::run_daemon();
                        }
                        "status" => slideshow::print_status(),
                        "toggle" => {
                            if let Err(e) = slideshow::toggle() {
                                eprintln!("{e}");
                            }
                        }
                        "pause" => {
                            if let Err(e) = slideshow::pause() {
                                eprintln!("{e}");
                            }
                        }
                        "resume" => {
                            if let Err(e) = slideshow::resume() {
                                eprintln!("{e}");
                            }
                        }
                        "next" => {
                            if let Err(e) = slideshow::next() {
                                eprintln!("{e}");
                            }
                        }
                        "prev" => {
                            if let Err(e) = slideshow::prev() {
                                eprintln!("{e}");
                            }
                        }
                        "set" => {
                            if let Err(e) = slideshow::handle_set(&args[4..]) {
                                eprintln!("{e}");
                            }
                        }
                        _ => eprintln!("Unknown slideshow command: {}", args[3]),
                    }
                }
                _ => print_usage(),
            }
        }

        "theme" => {
            if args.len() < 3 {
                if let Err(e) = palette::theme::apply() {
                    eprintln!("{e}");
                }
                return;
            }
            match args[2].as_str() {
                "apply" => {
                    if let Err(e) = palette::theme::apply() {
                        eprintln!("{e}");
                    }
                }
                "status" => palette::theme::print_status(),
                "presets-json" | "presets" => palette::presets::print_presets_json(),
                "apply-preset" | "preset" => {
                    if args.len() < 4 {
                        eprintln!("Missing preset ID");
                        return;
                    }
                    let preset_id = &args[3];
                    let mode = args.get(4).map(String::as_str);
                    if let Err(e) = palette::theme::apply_preset(preset_id, mode) {
                        eprintln!("{e}");
                    }
                }
                "apply-style" | "style" => {
                    if args.len() < 4 {
                        eprintln!("Missing style");
                        return;
                    }
                    let style = &args[3];
                    let mode = args.get(4).map(String::as_str);
                    if let Err(e) = palette::theme::apply_style(style, mode) {
                        eprintln!("{e}");
                    }
                }
                "apply-mode" | "mode" => {
                    if args.len() < 4 {
                        eprintln!("Missing mode (dark or light)");
                        return;
                    }
                    let mode = &args[3];
                    if let Err(e) = palette::theme::apply_mode(mode) {
                        eprintln!("{e}");
                    }
                }
                _ => eprintln!("Unknown theme command: {}", args[2]),
            }
        }

        "search" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "refresh" => search::refresh(),
                "query" => {
                    if args.len() < 4 {
                        eprintln!("Missing search query");
                        return;
                    }
                    search::query(&args[3..].join(" "));
                }
                "open" => {
                    if args.len() < 4 {
                        eprintln!("Missing search result target");
                        return;
                    }
                    search::open(&args[3..].join(" "));
                }
                "run" | "exec" => {
                    if args.len() < 4 {
                        eprintln!("Missing command to run");
                        return;
                    }
                    search::run(&args[3..].join(" "));
                }
                _ => print_usage(),
            }
        }

        "appLauncher" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "list" => appLauncher::list(),
                "index" => appLauncher::index_cli(),
                "search" => {
                    if args.len() < 4 {
                        eprintln!("Missing app search query");
                        return;
                    }
                    appLauncher::search(&args[3..].join(" "));
                }
                "launch" => {
                    if args.len() < 4 {
                        eprintln!("Missing application id");
                        return;
                    }
                    appLauncher::launch(&args[3]);
                }
                "refresh" => appLauncher::refresh(),
                _ => print_usage(),
            }
        }

        "island" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            island::call_action(&args[2]);
        }

        "qs" => {
            if args.len() < 4 {
                eprintln!("Usage: nexad qs <target> <method>");
                return;
            }
            if let Err(e) = island::call_qs(&args[2], &args[3]) {
                eprintln!("NEXA QS error: {e}");
            }
        }

        "shelf" | "tray" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "list" => {
                    let items = shelf::list();
                    match serde_json::to_string(&items) {
                        Ok(json) => println!("{json}"),
                        Err(e) => eprintln!("Error serializing shelf items: {e}"),
                    }
                }
                "add" => {
                    if args.len() < 4 {
                        eprintln!("Usage: nexad shelf add <path-or-uri> [path-or-uri ...]");
                        return;
                    }
                    let paths: Vec<&str> = args[3..].iter().map(|s| s.as_str()).collect();
                    match shelf::add_many(&paths) {
                        Ok(items) => {
                            for item in &items {
                                if let Ok(json) = serde_json::to_string(item) {
                                    println!("{json}");
                                }
                            }
                        }
                        Err(e) => eprintln!("Error adding to shelf: {e}"),
                    }
                }
                "remove" => {
                    if args.len() < 4 {
                        eprintln!("Usage: nexad shelf remove <id>");
                        return;
                    }
                    if let Err(e) = shelf::remove(&args[3]) {
                        eprintln!("Error removing from shelf: {e}");
                    } else {
                        println!("{{\"success\":true}}");
                    }
                }
                "clear" => {
                    if let Err(e) = shelf::clear() {
                        eprintln!("Error clearing shelf: {e}");
                    } else {
                        println!("{{\"success\":true}}");
                    }
                }
                "copy-all" | "copy" => match shelf::copy_all() {
                    Ok(msg) => println!("{{\"success\":true,\"message\":\"{msg}\"}}"),
                    Err(e) => eprintln!("Error copying shelf files: {e}"),
                },
                "copy-item" => {
                    if args.len() < 4 {
                        eprintln!("Usage: nexad shelf copy-item <id>");
                        return;
                    }
                    match shelf::copy_item(&args[3]) {
                        Ok(msg) => println!("{{\"success\":true,\"message\":\"{msg}\"}}"),
                        Err(e) => eprintln!("Error copying item: {e}"),
                    }
                }
                "toggle" => {
                    if let Err(e) = shelf::call_quickshell("toggle") {
                        eprintln!("Error toggling file shelf: {e}");
                    }
                }
                "open" => {
                    if let Err(e) = shelf::call_quickshell("open") {
                        eprintln!("Error opening file shelf: {e}");
                    }
                }
                "close" => {
                    if let Err(e) = shelf::call_quickshell("close") {
                        eprintln!("Error closing file shelf: {e}");
                    }
                }
                _ => print_usage(),
            }
        }

        "network" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            if args[2] == "watch" || args[2] == "daemon" {
                if let Err(e) = network::run_watch() {
                    eprintln!("Network watcher failed: {e}");
                }
                return;
            }
            if args.len() < 4 {
                print_usage();
                return;
            }
            let service = network::NetworkService::new();
            match args[2].as_str() {
                "wifi" => match args[3].as_str() {
                    "info" => match service.wifi_info() {
                        Ok(info) => println!("{}", serde_json::to_string(&info).unwrap()),
                        Err(e) => eprintln!("{e}"),
                    },
                    "scan" => match service.wifi_scan(false) {
                        Ok(net) => println!("{}", serde_json::to_string(&net).unwrap()),
                        Err(e) => eprintln!("{e}"),
                    },
                    "refresh" => match service.wifi_refresh() {
                        Ok(net) => println!("{}", serde_json::to_string(&net).unwrap()),
                        Err(e) => eprintln!("{e}"),
                    },
                    "on" => {
                        if let Err(e) = service.wifi_set_enabled(true) {
                            eprintln!("{e}");
                        }
                    }
                    "off" => {
                        if let Err(e) = service.wifi_set_enabled(false) {
                            eprintln!("{e}");
                        }
                    }
                    "connect" => {
                        if args.len() < 5 {
                            eprintln!("Missing SSID");
                            return;
                        }
                        let password = args.get(5).map(String::as_str);
                        if let Err(e) = service.wifi_connect(&args[4], password) {
                            eprintln!("{e}");
                        }
                    }
                    "disconnect" => {
                        if let Err(e) = service.wifi_disconnect() {
                            eprintln!("{e}");
                        }
                    }
                    "forget" => {
                        if args.len() < 5 {
                            eprintln!("Missing SSID");
                            return;
                        }
                        if let Err(e) = service.wifi_forget(&args[4]) {
                            eprintln!("{e}");
                        }
                    }
                    _ => print_usage(),
                },
                "bluetooth" => match args[3].as_str() {
                    "info" => match service.bluetooth_info() {
                        Ok(info) => println!("{}", serde_json::to_string(&info).unwrap()),
                        Err(e) => eprintln!("{e}"),
                    },
                    "on" => {
                        if let Err(e) = service.bluetooth_set_enabled(true) {
                            eprintln!("{e}");
                        }
                    }
                    "off" => {
                        if let Err(e) = service.bluetooth_set_enabled(false) {
                            eprintln!("{e}");
                        }
                    }
                    "scan" => {
                        if args.len() < 5 {
                            eprintln!("Missing scan state");
                            return;
                        }
                        let enabled = args[4].as_str() == "on";
                        if let Err(e) = service.bluetooth_scan(enabled) {
                            eprintln!("{e}");
                        }
                    }
                    "pair" => {
                        if args.len() < 5 {
                            eprintln!("Missing device address");
                            return;
                        }
                        if let Err(e) = service.bluetooth_pair(&args[4]) {
                            eprintln!("{e}");
                        }
                    }
                    "connect" => {
                        if args.len() < 5 {
                            eprintln!("Missing device address");
                            return;
                        }
                        if let Err(e) = service.bluetooth_connect(&args[4]) {
                            eprintln!("{e}");
                        }
                    }
                    "disconnect" => {
                        if args.len() < 5 {
                            eprintln!("Missing device address");
                            return;
                        }
                        if let Err(e) = service.bluetooth_disconnect(&args[4]) {
                            eprintln!("{e}");
                        }
                    }
                    "forget" => {
                        if args.len() < 5 {
                            eprintln!("Missing device address");
                            return;
                        }
                        if let Err(e) = service.bluetooth_forget(&args[4]) {
                            eprintln!("{e}");
                        }
                    }
                    _ => print_usage(),
                },
                _ => print_usage(),
            }
        }

        "screenshot" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "capture" => screenshot::capture(),
                _ => print_usage(),
            }
        }

        "snipping" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "capture" => snipping::capture(),
                _ => print_usage(),
            }
        }

        "workspace" => {
            if let Err(error) = workspace::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "recorder" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "start" => recorder::start(),
                "pause" => recorder::pause(),
                "resume" => recorder::resume(),
                "stop" => recorder::stop(),
                "toggle" => recorder::toggle(),
                "status" => recorder::status(),
                _ => print_usage(),
            }
        }

        "palette" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "media" | "matugen" => {
                    let source = if args.len() > 3 { args[3].as_str() } else { "" };
                    crate::palette::matugen::run_media_matugen(source);
                }
                "info" => {
                    if args.len() < 4 {
                        eprintln!("Missing wallpaper path");
                        return;
                    }
                    palette::print_info(&args[3]);
                }
                _ => print_usage(),
            }
        }

        "media" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "matugen" => {
                    let source = if args.len() > 3 { args[3].as_str() } else { "" };
                    media::run_matugen(source);
                }
                "fetch" => {
                    let title = if args.len() > 3 { args[3].as_str() } else { "" };
                    let artist = if args.len() > 4 { args[4].as_str() } else { "" };
                    media::run_fetch(title, artist);
                }
                "status" => {
                    let player = if args.len() > 3 { Some(args[3].as_str()) } else { None };
                    media::run_status(player);
                }
                "info" => media::run_info(),
                "watch" => media::watch_daemon(),
                "toggle" | "play-pause" => media::run_toggle(),
                "next" => media::run_next(),
                "prev" | "previous" => media::run_prev(),
                _ => print_usage(),
            }
        }

        "clipboard" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            match args[2].as_str() {
                "list" => clipboard::list(),
                "search" => {
                    if args.len() < 4 {
                        eprintln!("Missing clipboard search query");
                        return;
                    }
                    clipboard::search(&args[3..].join(" "));
                }
                "copy" => {
                    if args.len() < 4 {
                        eprintln!("Missing clipboard id");
                        return;
                    }
                    clipboard::copy(&args[3]);
                }
                "pin" => {
                    if args.len() < 4 {
                        eprintln!("Missing clipboard id");
                        return;
                    }
                    clipboard::pin(&args[3]);
                }
                "unpin" => {
                    if args.len() < 4 {
                        eprintln!("Missing clipboard id");
                        return;
                    }
                    clipboard::unpin(&args[3]);
                }
                "delete" => {
                    if args.len() < 4 {
                        eprintln!("Missing clipboard id");
                        return;
                    }
                    clipboard::delete(&args[3]);
                }
                "get" => {
                    if args.len() < 4 {
                        eprintln!("Missing clipboard id");
                        return;
                    }
                    clipboard::get(&args[3]);
                }
                "clear" => clipboard::clear(),
                "store-text" => clipboard::store_text(),
                "store-image" => clipboard::store_image(),
                _ => print_usage(),
            }
        }

        "notifications" => {
            let action = args.get(2).map(String::as_str).unwrap_or("list");
            match action {
                "daemon" => {
                    if let Err(e) = async_io::block_on(notifications::run_daemon()) {
                        eprintln!("notification daemon error: {e}");
                    }
                }
                "list" => notifications::list(),
                "dismiss" => {
                    let Some(id_str) = args.get(3) else {
                        eprintln!(
                            "usage: nexad notifications <daemon|list|dismiss|clear|read|read-all|action>"
                        );
                        return;
                    };
                    match id_str.parse::<u32>() {
                        Ok(id) => {
                            if let Err(e) = async_io::block_on(notifications::dismiss(id)) {
                                eprintln!("failed to dismiss notification: {e}");
                            }
                        }
                        Err(_) => eprintln!("invalid notification id"),
                    }
                }
                "clear" => {
                    if let Err(e) = async_io::block_on(notifications::clear()) {
                        eprintln!("failed to clear notifications: {e}");
                    }
                }
                "read" => {
                    let Some(id_str) = args.get(3) else {
                        eprintln!(
                            "usage: nexad notifications <daemon|list|dismiss|clear|read|read-all|action>"
                        );
                        return;
                    };
                    let id = match id_str.parse::<u32>() {
                        Ok(id) => id,
                        Err(_) => {
                            eprintln!("invalid notification id");
                            return;
                        }
                    };
                    if let Err(e) = async_io::block_on(notifications::read(id)) {
                        eprintln!("failed to mark notification read: {e}");
                    }
                }
                "read-all" => {
                    if let Err(e) = async_io::block_on(notifications::read_all()) {
                        eprintln!("failed to mark notifications read: {e}");
                    }
                }
                "action" => {
                    let (Some(id_str), Some(action_key)) = (args.get(3), args.get(4)) else {
                        eprintln!(
                            "usage: nexad notifications <daemon|list|dismiss|clear|read|read-all|action>"
                        );
                        return;
                    };
                    let id = match id_str.parse::<u32>() {
                        Ok(id) => id,
                        Err(_) => {
                            eprintln!("invalid notification id");
                            return;
                        }
                    };
                    if let Err(e) =
                        async_io::block_on(notifications::action(id, action_key.clone()))
                    {
                        eprintln!("failed to invoke notification action: {e}");
                    }
                }
                "dnd" => match args.get(3).map(String::as_str).unwrap_or("info") {
                    "info" => notifications::dnd_info(),
                    "on" => notifications::dnd_on(),
                    "off" => notifications::dnd_off(),
                    "toggle" => notifications::dnd_toggle(),
                    _ => eprintln!("usage: nexad notifications dnd <info|on|off|toggle>"),
                },
                _ => eprintln!(
                    "usage: nexad notifications <daemon|list|dismiss|clear|read|read-all|action>"
                ),
            }
        }

        "screenTemp" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            if let Err(error) = screenTemp::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "lock" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            if let Err(error) = lock::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "audio" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            if let Err(error) = audio::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "brightness" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            if let Err(error) = brightness::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "screenFilter" => {
            if let Err(error) = screenFilter::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "weather" => {
            if let Err(error) = weather::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "system" => {
            system::handle(&args[2..]);
        }

        "state" => {
            if let Err(error) = state::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "power" => {
            if args.len() < 3 {
                print_usage();
                return;
            }
            if let Err(error) = power::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "battery" => {
            if let Err(error) = battery::handle(&args[2..]) {
                eprintln!("{error}");
            }
        }

        "display" => {
            let code = display::run_cli(&args[2..]);
            if code != 0 {
                std::process::exit(code);
            }
        }

        "hypr" | "hyprland" => {
            hyprland::handle_command(&args[2..]);
        }

        "sound" => {
            if args.len() < 3 {
                if let Err(e) = sound::handle(&["get".to_string()]) {
                    eprintln!("{e}");
                }
                return;
            }
            if let Err(e) = sound::handle(&args[2..]) {
                eprintln!("{e}");
            }
        }

        _ => {
            print_usage();
        }
    }
}
