use serde::{Deserialize, Serialize};
use std::{collections::HashMap, path::PathBuf, time::SystemTime};

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct Config {
    pub path_entries: Vec<PathEntry>,
    pub config_path: PathBuf,
    #[serde(default = "default_excludes")]
    pub default_excludes: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PathEntry {
    pub path: PathBuf,
    pub prepend: bool,
    pub exclude_patterns: Vec<String>,
    pub max_depth: u8,
    #[serde(default)]
    pub discovered_paths: HashMap<PathBuf, exclude::Check>,
}
