mod cli;
mod config;
pub use config::Config;

fn main() {
    let _ = cli::init();
}
