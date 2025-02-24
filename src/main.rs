mod cli;
mod config;
mod utilities;
pub use config::Config;

fn main() {
    let _ = cli::init();
}
