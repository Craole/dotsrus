use super::exclude;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, path::PathBuf};

#[derive(Debug, Serialize, Deserialize)]
pub struct Path {
    pub path: PathBuf,
    pub prepend: bool,
    pub exclude_patterns: Vec<String>,
    pub max_depth: u8,
    #[serde(default)]
    pub discovered_paths: HashMap<PathBuf, exclude::Check>,
}
