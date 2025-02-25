use super::path;
use clap::Subcommand;

#[derive(Subcommand)]
pub enum Commands {
    /// Manage PATH entries
    Path {
        #[command(subcommand)]
        action: path::Commands,
    },

    /// Set and manage environment variables
    Set {
        /// Variable name
        name: String,

        /// Variable value
        value: Option<String>,

        /// Add a prefix to the variable name
        #[arg(long)]
        prefix: Option<String>,

        /// Add a suffix to the variable name
        #[arg(long)]
        suffix: Option<String>,

        /// Export the variable globally
        #[arg(long)]
        export: bool,

        /// Cache the variable for persistence
        #[arg(long)]
        cache: bool,

        /// Set as a path variable with path validation
        #[arg(long)]
        path: bool,

        /// Set as a command/executable with PATH lookup
        #[arg(long)]
        command: bool,
    },

    /// Show environment variables
    Show {
        /// Variable pattern to search for
        pattern: Option<String>,

        /// Show raw output without formatting
        #[arg(long)]
        raw: bool,
    },
}
