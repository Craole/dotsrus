use serde::{Deserialize, Serialize};
use std::time::SystemTime;

#[derive(Debug, Serialize, Deserialize, Clone)]
pub enum Reason {
    ExcludePattern(String), // Matched an exclude pattern
    GitIgnored,             // Matched gitignore rules
    DefaultExclude(String), // Matched default excludes
    NotDirectory,           // Path exists but isn't a directory
    DoesNotExist,           // Path doesn't exist
    PermissionDenied,       // No permission to access
    Other(String),          // Other reasons
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Check {
    pub timestamp: SystemTime,
    pub valid: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub invalid_reason: Option<Reason>,
}

pub fn default() -> Vec<String> {
    vec![
        "temp",
        "tmp",
        "*review*",
        "archive",
        "backup",
        "node_modules",
        "target",
        ".git",
    ]
    .into_iter()
    .map(String::from)
    .collect()
}

impl Check {
    pub fn new_valid() -> Self {
        Self {
            timestamp: SystemTime::now(),
            valid: true,
            invalid_reason: None,
        }
    }

    pub fn new_invalid(reason: Reason) -> Self {
        Self {
            timestamp: SystemTime::now(),
            valid: false,
            invalid_reason: Some(reason),
        }
    }
}
