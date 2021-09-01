use clap::{App, Arg, SubCommand};

async fn install(pkg: &str) -> String {
    match reqwest::get("http://example.com/".to_string() + pkg).await {
        Ok(req) => match req.text().await {
            Ok(body) => body,
            Err(_) => "".to_string(),
        },
        Err(_) => "".to_string(),
    }
}

#[tokio::main]
async fn main() -> Result<(), ()> {
    let matches = App::new("mkpm")
        .version("0.0.1")
        .author("Clay Risser <clayrisser@gmail.com>")
        .about("makefile package manager")
        .arg(
            Arg::with_name("verbose")
                .short("v")
                .long("verbose")
                .help("Verbose output"),
        )
        .subcommand(
            SubCommand::with_name("install")
                .about("Install makefile packages")
                .arg(
                    Arg::with_name("PACKAGE")
                        .help("Makefile package name")
                        .required(false)
                        .index(1),
                ),
        )
        .get_matches();
    if let Some(_) = matches.subcommand_matches("install") {
        println!("{}", install("hello").await);
    }
    Ok(())
}
