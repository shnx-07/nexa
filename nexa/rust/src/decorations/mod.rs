pub mod constellation_rail;

pub fn dispatch(args: &[String]) {
    if args.is_empty() {
        print_usage();
        return;
    }

    match args[0].as_str() {
        "list" => {
            println!("[\"constellation_rail\"]");
        }
        "constellation" | "constellation_rail" => {
            if let Err(e) = constellation_rail::handle_cli(&args[1..]) {
                eprintln!("{e}");
            }
        }
        _ => {
            eprintln!("Unknown decoration module: {}", args[0]);
            print_usage();
        }
    }
}

fn print_usage() {
    eprintln!("Usage: nexad decoration <constellation|list> [state|config|set|toggle]");
}

