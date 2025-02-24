use super::entry;
use super::exclude;
use directories::{BaseDirs, ProjectDirs};
use ignore::WalkBuilder;
use serde::{Deserialize, Serialize};
use std::{
    error::Error,
    fs::{self, File},
    io::{self, Write},
    path::{Path, PathBuf, MAIN_SEPARATOR, MAIN_SEPARATOR_STR},
};

#[derive(Debug, Serialize, Deserialize, Default)]
pub struct Config {
    pub path_entries: Vec<entry::Path>,
    pub config_path: PathBuf,
    #[serde(default = "exclude::default")]
    pub default_excludes: Vec<String>,
}

impl Config {
    pub fn new(custom_config_path: Option<&Path>) -> io::Result<Self> {
        let config_path = if let Some(path) = custom_config_path {
            path.to_path_buf()
        } else {
            let proj_dirs = ProjectDirs::from("com", "ccutils", env!("CARGO_PKG_NAME"))
                .expect("Failed to determine config directory");
            proj_dirs.config_dir().join("config.toml")
        };

        if !config_path.exists() {
            if let Some(parent) = config_path.parent() {
                fs::create_dir_all(parent)?;
            }
            File::create(&config_path)?;
            Ok(Config {
                path_entries: Vec::new(),
                config_path,
                default_excludes: exclude::default().into_iter().map(String::from).collect(),
            })
        } else {
            let content = fs::read_to_string(&config_path)?;
            let mut config: Config = toml::from_str(&content).unwrap_or_default();
            config.config_path = config_path;
            Ok(config)
        }
    }

    pub fn save(&self) -> Result<(), Box<dyn Error>> {
        let content = toml::to_string_pretty(self)?;
        fs::write(&self.config_path, content)?;
        self.update_shell_profile()?;
        Ok(())
    }

    fn update_shell_profile(&self) -> Result<(), Box<dyn Error>> {
        let base_dir = BaseDirs::new().expect("Failed to get base directories");
        let home_dir = base_dir.home_dir().to_path_buf();
        let profile_tag = "#| Dots 'R' Us";
        let profile_path = home_dir.join(".profile");
        let script_path = self.config_path.with_extension("env");

        //@ Create .profile if it doesn't exist
        if !profile_path.exists() {
            fs::File::create(&profile_path)?;
        }

        if profile_path.exists() {
            let content = fs::read_to_string(&profile_path)?;
            if !content.contains(profile_tag) {
                let mut file = fs::OpenOptions::new().append(true).open(&profile_path)?;
                writeln!(
                    file,
                    "\n{profile_tag}\n[ -f {script_path} ] && . {script_path}\n",
                    profile_tag = profile_tag,
                    script_path = script_path.display()
                )?;
            }
        }

        // Include possible shell profiles
        let shell_paths = vec![
            home_dir.join(".bashrc"),
            home_dir.join(".bash_profile"),
            home_dir.join(".bash_login"),
            home_dir.join(".zshrc"),
            home_dir.join(".zprofile"),
            home_dir.join(".config/fish/config.fish"),
        ];

        let source_lines = [
            //? For Bash and ZSH
            "\n[ -f \"$HOME/.profile\" ] && . \"$HOME/.profile\"\n",
            //? For Fish
            "\nif test -f ~/.profile; source ~/.profile; end\n",
        ];

        let index = 0;
        for shell_path in shell_paths {
            if !shell_path.exists() {
                //@ Create the shell config file if it doesn't exist
                let mut file = fs::File::create(shell_path.clone())?;
                if shell_path.ends_with("config.fish") {
                    //@ Use Fish syntax
                    writeln!(file, "{}", source_lines[1])?;
                } else {
                    //@ Use Bash/ZSH syntax
                    writeln!(file, "{}", source_lines[0])?;
                }
            } else {
                let content = fs::read_to_string(&shell_path)?;
                if shell_path.ends_with("config.fish") {
                    if !content.contains("source ~/.profile") {
                        let mut file = fs::OpenOptions::new().append(true).open(shell_path)?;
                        writeln!(file, "{}", source_lines[1])?;
                    }
                } else if !content.contains(". ~/.profile")
                    && !content.contains(". \"$HOME/.profile\"")
                {
                    let mut file = fs::OpenOptions::new().append(true).open(shell_path)?;
                    writeln!(file, "{}", source_lines[0])?;
                }
            }
        }

        //@ Generate shell script
        let mut script_contents = String::new();
        script_contents.push_str("#!/bin/sh\n\n");

        //@ Export current PATH first to preserve existing entries
        script_contents.push_str("export PATH=\"$PATH");

        //@ Add valid directories to PATH
        for entry in &self.path_entries {
            if entry.path.is_dir() {
                script_contents.push_str(&format!(":{}", entry.path.display()));
            }

            //@ Add only valid discovered directories
            for (discovered, status) in &entry.discovered_paths {
                if status.valid && discovered.is_dir() {
                    script_contents.push_str(&format!(":{}", discovered.display()));
                }
            }
        }

        //@ Print a trailing newline
        script_contents.push_str("\"\n");

        //@ Write the shell script
        fs::write(script_path, script_contents)?;

        Ok(())
    }

    pub fn should_exclude(&self, path: &Path, entry_excludes: &[String]) -> bool {
        let path_str = path.to_string_lossy().to_lowercase();
        let normalized_path = path_str.replace('/', MAIN_SEPARATOR_STR);

        //@ Split path into components using OS-specific separator
        let components: Vec<&str> = normalized_path
            .split(MAIN_SEPARATOR)
            .filter(|s| !s.is_empty())
            .collect();

        //@ Check each component against exclusion patterns
        for exclude in self.default_excludes.iter().chain(entry_excludes.iter()) {
            let exclude = exclude.to_lowercase();

            //@ Check full path
            if normalized_path.contains(&format!(
                "{}{}{}",
                MAIN_SEPARATOR_STR, exclude, MAIN_SEPARATOR_STR
            )) || normalized_path.ends_with(&format!("{}{}", MAIN_SEPARATOR_STR, exclude))
            {
                return true;
            }

            //@ Check individual components for exact matches
            if components.iter().any(|&c| c == exclude) {
                return true;
            }
        }

        //@ Check gitignore rules (unchanged)
        if let Some(parent) = path.parent() {
            let walker = WalkBuilder::new(parent)
                .hidden(true)
                .git_ignore(true)
                .ignore(true)
                .build();

            for entry in walker.flatten() {
                if entry.path() == path {
                    return entry.path().starts_with(".git") || entry.depth() == 0;
                }
            }
        }

        false
    }
}
