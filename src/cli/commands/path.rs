use crate::{
    config::{entry, exclude},
    utilities::component_matches_pattern,
    Config,
};
use clap::Subcommand;
use ignore::WalkBuilder;
use std::{
    collections::{HashMap, HashSet},
    error::Error,
    fs,
    path::{Component, Path, PathBuf},
};

#[derive(Subcommand)]
pub enum Commands {
    /// Add directory to PATH
    Add {
        /// Directories to add
        paths: Vec<PathBuf>,

        /// Add to start of PATH
        #[arg(long)]
        prepend: bool,

        /// Exclude patterns (comma-separated)
        #[arg(long)]
        exclude: Option<String>,

        /// Make scripts executable when adding (default: true)
        #[arg(long, default_value_t = true)]
        make_exec: bool,

        /// Maximum recursion depth (default: 5)
        #[arg(long, default_value_t = 5)]
        max_depth: u8,
    },

    /// Remove directory from PATH
    Remove {
        /// Directories to remove
        paths: Vec<PathBuf>,
    },

    /// Clean PATH of non-existent directories
    Clean,

    /// Show current PATH entries
    Show {
        /// Show raw output without formatting
        #[arg(long)]
        raw: bool,
    },

    /// Reset discovered paths and rescan
    Reset,
}

//@ Update Self implementation to use Config
impl Commands {
    pub fn execute(&self, config: &mut Config) -> Result<(), Box<dyn Error>> {
        match self {
            Self::Add {
                paths,
                prepend,
                exclude,
                make_exec,
                max_depth,
            } => {
                self.add_to_path(
                    paths,
                    *prepend,
                    exclude.as_deref(),
                    *make_exec,
                    *max_depth,
                    config,
                )?;
                self.refresh_recursive_paths(config)?;
            }
            Self::Remove { paths } => {
                self.remove_from_path(paths, config)?;
            }
            Self::Clean => {
                self.clean_path(config)?;
            }
            Self::Show { raw } => {
                self.show_path(*raw, config)?;
            }
            Self::Reset => {
                for entry in &mut config.path_entries {
                    entry.discovered_paths.clear();
                }
                self.refresh_recursive_paths(config)?;
            }
        }
        config.save()?;
        Ok(())
    }

    fn add_to_path(
        &self,
        paths: &[PathBuf],
        prepend: bool,
        exclude: Option<&str>,
        make_exec: bool,
        max_depth: u8,
        config: &mut Config,
    ) -> Result<(), Box<dyn Error>> {
        for path in paths {
            if !path.exists() {
                fs::create_dir_all(path)?;
            }

            let canonical_path = path.canonicalize()?;

            if make_exec {
                Self::make_scripts_executable(&canonical_path)?;
            }

            let exclude_patterns = exclude
                .map(|e| e.split(',').map(String::from).collect())
                .unwrap_or_default();

            let mut entry = entry::Path {
                path: canonical_path.clone(),
                prepend,
                exclude_patterns,
                max_depth,
                discovered_paths: HashMap::new(),
            };

            //@ Only scan if max_depth > 1
            if max_depth > 1 {
                let patterns = entry.exclude_patterns.clone();
                let default_excludes = config.default_excludes.clone();
                entry.discovered_paths =
                    self.scan_directory(&canonical_path, &patterns, &default_excludes, max_depth);
            }

            if !config.path_entries.iter().any(|e| e.path == entry.path) {
                if prepend {
                    config.path_entries.insert(0, entry);
                } else {
                    config.path_entries.push(entry);
                }
            }
        }
        Ok(())
    }

    fn refresh_recursive_paths(&self, config: &mut Config) -> Result<(), Box<dyn Error>> {
        // Clone the default excludes before the loop
        let default_excludes = config.default_excludes.clone();

        for entry in &mut config.path_entries {
            if entry.max_depth > 1 {
                let root_path = entry.path.clone();
                let patterns = entry.exclude_patterns.clone();

                // Pass default_excludes instead of the whole config
                let discovered = self.scan_directory(&root_path, &patterns, &default_excludes, 5);
                entry.discovered_paths = discovered;
            }
        }
        Ok(())
    }

    fn scan_directory(
        &self,
        path: &Path,
        exclude_patterns: &[String],
        default_excludes: &[String],
        max_depth: u8,
    ) -> HashMap<PathBuf, exclude::Check> {
        let mut discovered = HashMap::new();

        if !path.exists() {
            discovered.insert(
                path.to_path_buf(),
                exclude::Check::new_invalid(exclude::Reason::DoesNotExist),
            );
            return discovered;
        }

        if !path.is_dir() {
            discovered.insert(
                path.to_path_buf(),
                exclude::Check::new_invalid(exclude::Reason::NotDirectory),
            );
            return discovered;
        }

        let walker = WalkBuilder::new(path)
            .hidden(false)
            .git_ignore(true)
            .ignore(true)
            .max_depth(Some(max_depth as usize))
            .build();

        for result in walker {
            match result {
                Ok(dir_entry) => {
                    let path = dir_entry.path();

                    if !path.is_dir() {
                        continue;
                    }

                    // Get directory components
                    let components: Vec<_> = path
                        .components()
                        .filter_map(|comp| match comp {
                            Component::Normal(os_str) => os_str.to_str().map(|s| s.to_lowercase()),
                            _ => None,
                        })
                        .collect();

                    // Check if any component exactly matches our patterns
                    let is_excluded = components.iter().any(|component| {
                        exclude_patterns
                            .iter()
                            .any(|pattern| component_matches_pattern(component, pattern))
                            || default_excludes
                                .iter()
                                .any(|pattern| component_matches_pattern(component, pattern))
                    });

                    if is_excluded {
                        // Find which pattern matched for better error reporting
                        let matching_pattern = exclude_patterns
                            .iter()
                            .find(|pattern| {
                                components
                                    .iter()
                                    .any(|comp| component_matches_pattern(comp, pattern))
                            })
                            .cloned()
                            .map(exclude::Reason::ExcludePattern)
                            .or_else(|| {
                                default_excludes
                                    .iter()
                                    .find(|pattern| {
                                        components
                                            .iter()
                                            .any(|comp| component_matches_pattern(comp, pattern))
                                    })
                                    .cloned()
                                    .map(exclude::Reason::DefaultExclude)
                            });

                        discovered.insert(
                            path.to_path_buf(),
                            exclude::Check::new_invalid(matching_pattern.unwrap_or(
                                exclude::Reason::Other("Unknown pattern match".to_string()),
                            )),
                        );
                        continue;
                    }

                    // Check git ignore rules
                    if components.iter().any(|comp| comp == ".git") {
                        discovered.insert(
                            path.to_path_buf(),
                            exclude::Check::new_invalid(exclude::Reason::GitIgnored),
                        );
                        continue;
                    }

                    // If we get here, the path is valid
                    discovered.insert(path.to_path_buf(), exclude::Check::new_valid());
                }
                Err(err) => {
                    let reason = match err.io_error() {
                        Some(io_err) => match io_err.kind() {
                            std::io::ErrorKind::PermissionDenied => {
                                exclude::Reason::PermissionDenied
                            }
                            _ => exclude::Reason::Other(err.to_string()),
                        },
                        None => exclude::Reason::Other(err.to_string()),
                    };

                    discovered.insert(path.to_path_buf(), exclude::Check::new_invalid(reason));
                }
            }
        }
        discovered
    }

    // Modified show_path implementation to display invalid paths
    fn show_path(&self, raw: bool, config: &Config) -> Result<(), Box<dyn Error>> {
        if raw {
            for entry in &config.path_entries {
                println!("{}", entry.path.display());
                for (path, check) in &entry.discovered_paths {
                    let status = if check.valid {
                        "valid".to_string()
                    } else {
                        format!("invalid: {:?}", check.invalid_reason.as_ref().unwrap())
                    };
                    println!("  {} ({})", path.display(), status);
                }
            }
        } else {
            println!("Configured PATH entries:");
            for entry in &config.path_entries {
                println!(
                    "{} (prepend: {}, recursive: {}, exclude: {:?})",
                    entry.path.display(),
                    entry.prepend,
                    entry.max_depth,
                    entry.exclude_patterns
                );

                println!("Discovered directories:");
                let (valid, invalid): (Vec<_>, Vec<_>) = entry
                    .discovered_paths
                    .iter()
                    .partition(|(_, check)| check.valid);

                if !valid.is_empty() {
                    println!("  Valid paths:");
                    for (path, _) in valid {
                        println!("    {}", path.display());
                    }
                }

                if !invalid.is_empty() {
                    println!("  Invalid paths:");
                    for (path, check) in invalid {
                        println!(
                            "    {} (Reason: {:?})",
                            path.display(),
                            check.invalid_reason.as_ref().unwrap()
                        );
                    }
                }
            }
        }
        Ok(())
    }

    fn remove_from_path(
        &self,
        paths: &[PathBuf],
        config: &mut Config,
    ) -> Result<(), Box<dyn Error>> {
        let paths_to_remove: HashSet<_> =
            paths.iter().filter_map(|p| p.canonicalize().ok()).collect();

        config
            .path_entries
            .retain(|entry| !paths_to_remove.contains(&entry.path));
        Ok(())
    }

    fn clean_path(&self, config: &mut Config) -> Result<(), Box<dyn Error>> {
        config.path_entries.retain(|entry| entry.path.exists());
        Ok(())
    }

    fn make_scripts_executable(path: &Path) -> Result<(), Box<dyn Error>> {
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            let path = entry.path();
            if path.is_file() {
                let mut perms = fs::metadata(&path)?.permissions();
                #[cfg(unix)]
                {
                    use std::os::unix::fs::PermissionsExt;
                    perms.set_mode(0o755);
                }
                #[cfg(not(unix))]
                {
                    perms.set_readonly(false);
                }
                fs::set_permissions(&path, perms)?;
            }
        }
        Ok(())
    }
}
