use crate::{
    config::{LastCheck, PathEntry},
    Config,
};
use clap::Subcommand;
use ignore::WalkBuilder;
use std::{
    collections::{HashMap, HashSet},
    error::Error,
    fs,
    path::{Path, PathBuf},
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

            let mut entry = PathEntry {
                path: canonical_path.clone(),
                prepend,
                exclude_patterns,
                max_depth,
                discovered_paths: HashMap::new(),
            };

            //@ Only scan if max_depth > 1
            if max_depth > 1 {
                let patterns = entry.exclude_patterns.clone();
                self.scan_directory(&canonical_path, &mut entry, &patterns, max_depth)?;
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

    fn scan_directory(
        &self,
        path: &Path,
        entry: &mut PathEntry,
        exclude_patterns: &[String],
        max_depth: u8,
    ) -> Result<(), Box<dyn Error>> {
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
                    if path.is_dir() {
                        // Check against exclude patterns
                        let path_str = path.to_string_lossy().to_lowercase();
                        let should_exclude = exclude_patterns
                            .iter()
                            .any(|pattern| path_str.contains(pattern));

                        if !should_exclude {
                            entry.discovered_paths.insert(
                                path.to_path_buf(),
                                LastCheck {
                                    timestamp: std::time::SystemTime::now(),
                                    valid: true,
                                },
                            );
                        }
                    }
                }
                Err(err) => eprintln!("Error walking directory: {}", err),
            }
        }
        Ok(())
    }

    fn refresh_recursive_paths(&self, config: &mut Config) -> Result<(), Box<dyn Error>> {
        for entry in &mut config.path_entries {
            if entry.max_depth > 1 {
                let root_path = entry.path.clone();
                let patterns = entry.exclude_patterns.clone();
                entry.discovered_paths.clear();
                // Use the default max_depth for refreshing
                self.scan_directory(&root_path, entry, &patterns, 5)?;
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

    fn show_path(&self, raw: bool, config: &Config) -> Result<(), Box<dyn Error>> {
        if raw {
            for entry in &config.path_entries {
                println!("{}", entry.path.display());
                for discovered in entry.discovered_paths.keys() {
                    println!("  {}", discovered.display());
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
                for discovered in entry.discovered_paths.keys() {
                    println!("  {}", discovered.display());
                }
            }
        }
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
