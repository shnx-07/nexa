#[allow(non_snake_case)]
mod appLauncher;
#[allow(non_snake_case)]
mod screenTemp;

#[allow(non_snake_case)]
mod screenFilter;
mod weather;
mod workspace;
mod command;
mod island;
mod network;
mod system;
mod search;
mod wallpaper;
mod screenshot;
mod snipping;
mod recorder;
mod clipboard;
mod notifications;
mod lock;
mod power;
mod audio;
mod brightness;

use std::env;


fn print_usage() {
    eprintln!(
        "Usage:
  nexad wallpaper list
  nexad wallpaper search <query>
  nexad wallpaper refresh

  nexad wallpaper lock-set <path>
  nexad wallpaper lock-info

  nexad search refresh
  nexad search query <query>
  nexad search open <id>


  nexad workspace info
  nexad workspace switch <1-10>
  nexad workspace focus <address>
  nexad workspace special <name>

  nexad command run <command>

  nexad island search
  nexad island command

  nexad network wifi info
  nexad network wifi scan
  nexad network wifi refresh
  nexad network wifi on|off
  nexad network wifi connect <ssid> [password]
  nexad network wifi disconnect
  nexad network wifi forget <ssid>

  nexad network bluetooth info
  nexad network bluetooth on|off
  nexad network bluetooth scan on|off
  nexad network bluetooth pair <address>
  nexad network bluetooth connect <address>
  nexad network bluetooth disconnect <address>
  nexad network bluetooth forget <address>

  nexad appLauncher list
  nexad appLauncher search <query>
  nexad appLauncher launch <id>
  nexad appLauncher refresh
  
  nexad screenshot capture
  nexad snipping capture

  nexad recorder start
  nexad recorder pause
  nexad recorder resume
  nexad recorder stop
  nexad recorder toggle
  nexad recorder status

  nexad clipboard list
  nexad clipboard search <query>
  nexad clipboard copy <id>
  nexad clipboard delete <id>
  nexad clipboard clear
  nexad clipboard get <id>

  nexad screenTemp info
  nexad screenTemp enable
  nexad screenTemp disable
  nexad screenTemp toggle

  nexad screenTemp mode manual
  nexad screenTemp mode wallpaper
  nexad screenTemp mode night

  nexad screenTemp set <kelvin>
  nexad screenTemp wallpaper-set <kelvin>
  nexad screenTemp night-set <kelvin>

  nexad screenTemp apply
  nexad screenTemp reset

  nexad notifications daemon
  nexad notifications list
  nexad notifications dismiss ID
  nexad notifications clear
  nexad notifications read
  nexad notifications action
  nexad notifications dnd info
  nexad notifications dnd on
  nexad notifications dnd off
  nexad notifications dnd toggle

  nexad power lock
  nexad power suspend
  nexad power logout
  nexad power reboot
  nexad power shutdown

  nexad lock auth
  
  nexad audio info
  nexad audio set <0-100>
  nexad audio mute
  nexad audio unmute
  nexad audio toggle-mute

  nexad brightness info
  nexad brightness set <1-100>
  nexad brightness up [amount]
  nexad brightness down [amount]

  nexad system airplane info
  nexad system airplane on
  nexad system airplane off
  nexad system airplane toggle

  nexad system vpn info
  nexad system vpn connect <profile>
  nexad system vpn disconnect
  nexad system vpn toggle

  nexad screenFilter info
  nexad screenFilter set chroma
  nexad screenFilter set grayscale
  nexad screenFilter set hdr-boost
  nexad screenFilter set high-contrast
  nexad screenFilter set invert
  nexad screenFilter set sepia
  nexad screenFilter off
  nexad screenFilter apply

  "
    );
}


fn main() {
    let args: Vec<String> =
        env::args().collect();


    if args.len() < 2 {
        print_usage();
        return;
    }


    match args[1].as_str() {

        // ========================================================
        // WALLPAPER
        // ========================================================

        "wallpaper" => {
            if args.len() < 3 {
                print_usage();
                return;
            }


            match args[2].as_str() {

                "list" => {
                    wallpaper::print_list();
                }


                "search" => {
                    if args.len() < 4 {
                        eprintln!("Missing search query");
                        return;
                    }

                    let query =
                        args[3..].join(" ");

                    wallpaper::print_search(
                        &query
                    );
                }

                "lock-set" => {
                    if args.len() < 4 {
                        eprintln!(
                            "Missing lock wallpaper path"
                        );

                        return;
                    }


                    let path =
                        args[3..].join(" ");


                    if let Err(error) =
                        wallpaper::set_lock(&path)
                    {
                        eprintln!("{error}");
                    }
                }


                "lock-info" => {
                    if let Err(error) =
                        wallpaper::print_lock_info()
                    {
                        eprintln!("{error}");
                    }
                }


                "refresh" => {
                    wallpaper::refresh();
                }


                _ => {
                    print_usage();
                }
            }
        }


        // ========================================================
        // SEARCH
        // ========================================================

        "search" => {
            if args.len() < 3 {
                print_usage();
                return;
            }


            match args[2].as_str() {

                "refresh" => {
                    search::refresh();
                }


                "query" => {
                    if args.len() < 4 {
                        eprintln!(
                            "Missing search query"
                        );

                        return;
                    }


                    let query =
                        args[3..].join(" ");


                    search::query(
                        &query
                    );
                }


                "open" => {
                    if args.len() < 4 {
                        eprintln!(
                            "Missing search result id"
                        );

                        return;
                    }


                    let id =
                        match args[3].parse::<usize>() {

                            Ok(id) => id,

                            Err(_) => {
                                eprintln!(
                                    "Invalid search result id"
                                );

                                return;
                            }
                        };


                    search::open(id);
                }


                _ => {
                    print_usage();
                }
            }
        }

        // ========================================================
        // APP LAUNCHER
        // ========================================================

        "appLauncher" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            match args[2].as_str() {
                "list" => {
                    appLauncher::list();
                }

                "search" => {
                    if args.len() < 4 {
                        eprintln!("Missing app search query");
                        return;
                    }

                    let query =
                        args[3..].join(" ");

                    appLauncher::search(
                        &query
                    );
                }

                "launch" => {
                    if args.len() < 4 {
                        eprintln!("Missing application id");
                        return;
                    }

                    appLauncher::launch(
                        &args[3]
                    );
                }

                "refresh" => {
                    appLauncher::refresh();
                }

                _ => {
                    print_usage();
                }
            }
        }

        // ========================================================
        // ISLAND
        // ========================================================

        "island" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            match args[2].as_str() {
                "search" => {
                    island::open_search();
                }

                "command" => {
                    island::open_command();
                }

                _ => {
                    print_usage();
                }
            }
        }


        // ========================================================
        // NETWORK
        // ========================================================

        "network" => {
            if args.len() < 4 {
                print_usage();
                return;
            }

            let service = network::NetworkService::new();

            match args[2].as_str() {

                // ------------------------------------------------
                // WIFI
                // ------------------------------------------------

                "wifi" => {
                    match args[3].as_str() {

                        "info" => {
                            match service.wifi_info() {
                                Ok(info) => {
                                    println!(
                                        "{}",
                                        serde_json::to_string(&info).unwrap()
                                    );
                                }

                                Err(error) => {
                                    eprintln!("{error}");
                                }
                            }
                        }


                        "scan" => {
                            match service.wifi_scan(false) {
                                Ok(networks) => {
                                    println!(
                                        "{}",
                                        serde_json::to_string(&networks).unwrap()
                                    );
                                }

                                Err(error) => {
                                    eprintln!("{error}");
                                }
                            }
                        }


                        "refresh" => {
                            match service.wifi_refresh() {
                                Ok(networks) => {
                                    println!(
                                        "{}",
                                        serde_json::to_string(&networks).unwrap()
                                    );
                                }

                                Err(error) => {
                                    eprintln!("{error}");
                                }
                            }
                        }


                        "on" => {
                            if let Err(error) =
                                service.wifi_set_enabled(true)
                            {
                                eprintln!("{error}");
                            }
                        }


                        "off" => {
                            if let Err(error) =
                                service.wifi_set_enabled(false)
                            {
                                eprintln!("{error}");
                            }
                        }


                        "connect" => {
                            if args.len() < 5 {
                                eprintln!("Missing SSID");
                                return;
                            }

                            let ssid = &args[4];

                            let password =
                                args.get(5)
                                    .map(String::as_str);

                            if let Err(error) =
                                service.wifi_connect(
                                    ssid,
                                    password
                                )
                            {
                                eprintln!("{error}");
                            }
                        }


                        "disconnect" => {
                            if let Err(error) =
                                service.wifi_disconnect()
                            {
                                eprintln!("{error}");
                            }
                        }


                        "forget" => {
                            if args.len() < 5 {
                                eprintln!("Missing SSID");
                                return;
                            }

                            if let Err(error) =
                                service.wifi_forget(&args[4])
                            {
                                eprintln!("{error}");
                            }
                        }


                        _ => {
                            print_usage();
                        }
                    }
                }


                // ------------------------------------------------
                // BLUETOOTH
                // ------------------------------------------------

                "bluetooth" => {
                    match args[3].as_str() {

                        "info" => {
                            match service.bluetooth_info() {
                                Ok(info) => {
                                    println!(
                                        "{}",
                                        serde_json::to_string(&info).unwrap()
                                    );
                                }

                                Err(error) => {
                                    eprintln!("{error}");
                                }
                            }
                        }


                        "on" => {
                            if let Err(error) =
                                service.bluetooth_set_enabled(true)
                            {
                                eprintln!("{error}");
                            }
                        }


                        "off" => {
                            if let Err(error) =
                                service.bluetooth_set_enabled(false)
                            {
                                eprintln!("{error}");
                            }
                        }


                        "scan" => {
                            if args.len() < 5 {
                                eprintln!("Missing scan state");
                                return;
                            }

                            let enabled =
                                args[4].as_str() == "on";

                            if let Err(error) =
                                service.bluetooth_scan(enabled)
                            {
                                eprintln!("{error}");
                            }
                        }


                        "pair" => {
                            if args.len() < 5 {
                                eprintln!("Missing device address");
                                return;
                            }

                            if let Err(error) =
                                service.bluetooth_pair(&args[4])
                            {
                                eprintln!("{error}");
                            }
                        }


                        "connect" => {
                            if args.len() < 5 {
                                eprintln!("Missing device address");
                                return;
                            }

                            if let Err(error) =
                                service.bluetooth_connect(&args[4])
                            {
                                eprintln!("{error}");
                            }
                        }


                        "disconnect" => {
                            if args.len() < 5 {
                                eprintln!("Missing device address");
                                return;
                            }

                            if let Err(error) =
                                service.bluetooth_disconnect(&args[4])
                            {
                                eprintln!("{error}");
                            }
                        }


                        "forget" => {
                            if args.len() < 5 {
                                eprintln!("Missing device address");
                                return;
                            }

                            if let Err(error) =
                                service.bluetooth_forget(&args[4])
                            {
                                eprintln!("{error}");
                            }
                        }


                        _ => {
                            print_usage();
                        }
                    }
                }


                _ => {
                    print_usage();
                }
            }
        }


        // ========================================================
        // COMMAND
        // ========================================================

        "command" => {
            if args.len() < 4 {
                print_usage();
                return;
            }


            match args[2].as_str() {

                "run" => {
                    let command =
                        args[3..].join(" ");


                    command::run(
                        &command
                    );
                }


                _ => {
                    print_usage();
                }
            }
        }

        // ========================================================
        // SCREENSHOT
        // ========================================================



        "screenshot" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            match args[2].as_str() {
                "capture" => {
                    screenshot::capture();
                }

                _ => {
                    print_usage();
                }
            }
        }

        // ========================================================
        // SNIPPING
        // ========================================================


        "snipping" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            match args[2].as_str() {
                "capture" => {
                    snipping::capture();
                }

                _ => {
                    print_usage();
                }
            }
        }
        
        // ========================================================
        // WORKSPACE
        // ========================================================

        "workspace" => {
            if let Err(error) =
                workspace::handle(
                    &args[2..]
                )
            {
                eprintln!("{error}");
            }
        }
        // ========================================================
        // SCREEN RECORDER
        // ========================================================

        "recorder" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            match args[2].as_str() {
                "start" => {
                    recorder::start();
                }

                "pause" => {
                    recorder::pause();
                }

                "resume" => {
                    recorder::resume();
                }

                "stop" => {
                    recorder::stop();
                }

                "toggle" => {
                    recorder::toggle();
                }

                "status" => {
                    recorder::status();
                }

                _ => {
                    print_usage();
                }
            }
        }

        // ========================================================
        // CLIPBOARD
        // ========================================================

        "clipboard" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            match args[2].as_str() {
                "list" => {
                    clipboard::list();
                }

                "search" => {
                    if args.len() < 4 {
                        eprintln!("Missing clipboard search query");
                        return;
                    }

                    let query =
                        args[3..].join(" ");

                    clipboard::search(&query);
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

                "clear" => {
                    clipboard::clear();
                }

                _ => {
                    print_usage();
                }
            }
        }


        // ========================================================
        // notifications
        // ========================================================


        "notifications" => {
            let action = args
                .get(2)
                .cloned()
                .unwrap_or_else(|| "list".to_string());

            match action.as_str() {

                "daemon" => {
                    if let Err(error) =
                        async_io::block_on(
                            notifications::run_daemon()
                        )
                    {
                        eprintln!(
                            "notification daemon error: {error}"
                        );
                    }
                }


                "list" => {
                    notifications::list();
                }


                "dismiss" => {
                    let Some(id) = args.get(3) else {
                        eprintln!(
                            "usage: nexad notifications \
                            <daemon|list|dismiss|clear|read|read-all|action>"
                            );

                        return;
                    };


                    match id.parse::<u32>() {

                        Ok(id) => {
                            if let Err(error) =
                                async_io::block_on(
                                    notifications::dismiss(id)
                                )
                            {
                                eprintln!(
                                    "failed to dismiss notification: {error}"
                                );
                            }
                        }


                        Err(_) => {
                            eprintln!(
                                "invalid notification id"
                            );
                        }
                    }
                }


                "clear" => {
                    if let Err(error) =
                        async_io::block_on(
                            notifications::clear()
                        )
                    {
                        eprintln!(
                            "failed to clear notifications: {error}"
                        );
                    }
                }


                "read" => {
                    let Some(id) = args.get(3) else {
                        eprintln!(
                            "usage: nexad notifications \
                            <daemon|list|dismiss|clear|read|read-all|action>"                        
                            );
                        return;
                    };

                    let id = match id.parse::<u32>() {
                        Ok(id) => id,

                        Err(_) => {
                            eprintln!("invalid notification id");
                            return;
                        }
                    };

                    if let Err(error) =
                        async_io::block_on(
                            notifications::read(id)
                        )
                    {
                        eprintln!(
                            "failed to mark notification read: {error}"
                        );
                    }
                }

                "read-all" => {
                    if let Err(error) =
                        async_io::block_on(
                            notifications::read_all()
                        )
                    {
                        eprintln!(
                            "failed to mark notifications read: {error}"
                        );
                    }
                }

                "action" => {
                    let Some(id) = args.get(3) else {
                        eprintln!(
                            "usage: nexad notifications \
                            <daemon|list|dismiss|clear|read|read-all|action>"                        
                            );
                        return;
                    };

                    let Some(action_key) = args.get(4) else {
                        eprintln!(
                            "usage: nexad notifications \
                            <daemon|list|dismiss|clear|read|read-all|action>"                        
                            );
                        return;
                    };

                    let id = match id.parse::<u32>() {
                        Ok(id) => id,

                        Err(_) => {
                            eprintln!("invalid notification id");
                            return;
                        }
                    };

                    if let Err(error) =
                        async_io::block_on(
                            notifications::action(
                                id,
                                action_key.clone(),
                            )
                        )
                    {
                        eprintln!(
                            "failed to invoke notification action: {error}"
                        );
                    }
                }
                

                "dnd" => {
                    let dnd_action =
                        args
                            .get(3)
                            .map(
                                String::as_str
                            )
                            .unwrap_or(
                                "info"
                            );


                    match dnd_action {
                        "info" => {
                            notifications::dnd_info();
                        }

                        "on" => {
                            notifications::dnd_on();
                        }

                        "off" => {
                            notifications::dnd_off();
                        }

                        "toggle" => {
                            notifications::dnd_toggle();
                        }

                        _ => {
                            eprintln!(
                                "usage: nexad notifications dnd <info|on|off|toggle>"
                            );
                        }
                    }
                }
                
                _ => {
                    eprintln!(
                            "usage: nexad notifications \
                            <daemon|list|dismiss|clear|read|read-all|action>"
                    );
                }
            }
        }


        // ========================================================
        // SCREEN TEMPERATURE
        // ========================================================

        "screenTemp" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            if let Err(error) =
                screenTemp::handle(&args[2..])
            {
                eprintln!("{error}");
            }
        }

        // ========================================================
        // LOCK SCREEN
        // ========================================================

        "lock" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            if let Err(error) =
                lock::handle(&args[2..])
            {
                eprintln!("{error}");
            }
        }


        // ========================================================
        // AUDIO
        // ========================================================

        "audio" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            if let Err(error) =
                audio::handle(&args[2..])
            {
                eprintln!("{error}");
            }
        }


        // ========================================================
        // BRIGHTNESS
        // ========================================================

        "brightness" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            if let Err(error) =
                brightness::handle(&args[2..])
            {
                eprintln!("{error}");
            }
        }

        // ========================================================
        // SCREEN FILTER
        // ========================================================

        "screenFilter" => {
            if let Err(error) =
                screenFilter::handle(
                    &args[2..]
                )
            {
                eprintln!("{error}");
            }
        }
       

        // ========================================================
        // WEATHER
        // ========================================================

        "weather" => {
            if let Err(error) =
                weather::handle(
                    &args[2..]
                )
            {
                eprintln!("{error}");
            }
        }

        // ========================================================
        // SYSTEM
        // ========================================================

        "system" => {
            system::handle(
                &args[2..]
            );
        }


        // ========================================================
        // POWER
        // ========================================================

        "power" => {
            if args.len() < 3 {
                print_usage();
                return;
            }

            if let Err(error) =
                power::handle(&args[2..])
            {
                eprintln!("{error}");
            }
        }

        // ========================================================
        // UNKNOWN
        // ========================================================

        _ => {
            print_usage();
        }
    }
}
