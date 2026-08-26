use pam::Client;
use serde_json::json;
use std::env;
use std::io;


pub fn handle(args: &[String]) -> Result<(), String> {
    if args.is_empty() {
        return Err(
            "Usage: nexad lock auth".to_string()
        );
    }

    match args[0].as_str() {
        "auth" => authenticate_from_stdin(),

        action => Err(
            format!(
                "Unknown lock action: {action}"
            )
        ),
    }
}


fn authenticate_from_stdin() -> Result<(), String> {
    let username =
        env::var("USER")
            .map_err(
                |_| "Unable to determine current user".to_string()
            )?;


    // Password comes from stdin instead of argv.
    let mut password = String::new();

    io::stdin()
        .read_line(&mut password)
        .map_err(
            |error|
                format!(
                    "Unable to read password: {error}"
                )
        )?;

    let password =
        password
            .trim_end_matches(['\r', '\n']);


    let mut client =
        Client::with_password("system-auth")
            .map_err(
                |error|
                    format!(
                        "Unable to initialize PAM: {error}"
                    )
            )?;


    client
        .conversation_mut()
        .set_credentials(
            &username,
            password
        );


    match client.authenticate() {
        Ok(()) => {
            println!(
                "{}",
                json!({
                    "success": true
                })
            );

            Ok(())
        }


        Err(_) => {
            println!(
                "{}",
                json!({
                    "success": false
                })
            );

            Ok(())
        }
    }
}
