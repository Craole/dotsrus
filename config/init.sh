#!/bin/sh
# shellcheck disable=SC2034

helpers_init() {
	print_block() {
		printf "%s\n\n" "$*"
	}

	print_status() {
		unset app icon dep err
		while [ "$#" -gt 0 ]; do
			case "$1" in
			--success) icon="🟢" ;;
			--failure) icon="🔴" ;;
			--app) [ "$2" ] && app="$2" ;;
			--dependency) [ "$2" ] && dep="$2" ;;
			--error) [ "$2" ] && err="$2" ;;
			esac
			shift
		done

		[ "$app" ] && printf "%s %s\n" "$icon" "$app"
		[ "$dep" ] && {
			tput setaf 1
			printf "Missing dependency: " >&2
			tput sgr0
			printf "%s\n" "$dep" >&2
		}
		[ "$err" ] && {
			tput setaf 1
			printf "Error: %s\n" "$err" >&2
			tput sgr0
		}
	}

	print_heading() {
		tput setaf 4
		printf "|> %s <|\n" "$*"
		tput sgr0
	}

	app_available() {
		command -v "$1" >/dev/null 2>&1
	}

	pathof_flake_or_git() {
		#? Check if the current directory or any parent directory has a flake.nix file
		dir="$PWD"
		while [ "$dir" != "/" ]; do
			if [ -f "$dir/flake.nix" ]; then
				printf "%s" "$dir"
				return 0
			fi
			dir=$(dirname "$dir")
		done

		#? In the unlikely event that this is not a Flake, check if the current directory or any parent directory is a Git repository
		if git rev-parse --show-toplevel >/dev/null 2>&1; then
			git rev-parse --show-toplevel
		else
			#? If not a Git repository, print an error message and exit
			print_status --error "Failed to determine the project root (either a Flake or Git repository)"
			return 2
		fi
	}

	create_file() {
		while [ "$#" -gt 0 ]; do

			#? Create the parent directory if it doesn't exist
			case "$1" in
			*/*) mkdir --parents "$(dirname "$1")" ;;
			esac

			#? Create the file
			touch "$1"

			shift
		done
	}

	find_first() {
		search_root="$PRJ_ROOT"
		search_depth=2
		search_type="file"

		while [ "$#" -gt 0 ]; do
			case "$1" in
			--path) [ "$2" ] && search_root=$2 ;;
			--target) [ "$2" ] && search_target="$2" ;;
			--depth) [ "$2" ] && search_depth="$2" ;;
			--type) search_type="$2" ;;
			*) search_target="$1" ;;
			esac
			shift
		done

		search_type="${search_type%"${search_type#?}"}"

		find \
			-L "$search_root" \
			-maxdepth "$search_depth" \
			-type "$search_type" \
			-iname "$search_target" |
			head -n1
	}
}

project_info() {

	variables() {
		#@ Variables @#
		#| Project Root Directory
		set -o allexport
		if pathof_flake_or_git >/dev/null 2>&1; then
			PRJ_ROOT="$(pathof_flake_or_git)"
		else
			pathof_flake_or_git
			return "$?"
		fi

		#| Project Config Directory
		PRJ_CONF="$(dirname "$(find_first --target "init*")")"

		#| Project Readme
		PRJ_INFO="$(find_first --target "readme*")"

		#| Project Name
		PRJ_NAME="$(basename "$PRJ_ROOT" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')"

		#| Direnv Log Format
		app_available direnv && DIRENV_LOG_FORMAT=""

		#| Just
		app_available just && {
			JUST_JUSTFILE="$(find_first --target "justfile")"
			JUST_UNSTABLE=true
		}

		set +o allexport

		print_heading "Variables"
		print_block "$(
			for var in PRJ_NAME PRJ_ROOT PRJ_CONF PRJ_INFO; do
				eval "val=\$$var"
				[ -n "$val" ] && printf '%s=%s\n' "$var" "$val"
			done

			app_available just && {

				for var in JUST_JUSTFILE JUST_UNSTABLE; do
					eval "val=\$$var"
					[ -n "$val" ] && printf '%s=%s\n' "$var" "$val"
				done
			}
		)"
	}

	aliases() {
		#@ Aliases @#
		app_available bat && alias cat='bat --style=plain'

		app_available cargo && alias A='cargo add'
		app_available cargo && alias B='cargo build --release'
		app_available cargo && alias C='project_clean'
		app_available dust && alias D='cargo remove'
		app_available hx && alias E='hx'
		alias F='project_format'
		app_available cargo && alias G='cargo generate'
		app_available hx && alias H='hx "$PRJ_ROOT"'
		alias I='project_init'
		app_available just && alias J='just'
		alias K='exit'
		if app_available eza; then
			alias ls='eza --almost-all --group-directories-first --color=always --icons=always --git --git-ignore --time-style relative --total-size --smart-group'
			alias L='ls --long '
			alias La='ls --long --git'
			alias Lt='L --tree'
		elif app_available lsd; then
			alias ls='lsd --almost-all --group-directories-first --color=always'
			alias L='ls --long --git --date=relative --versionsort --total-size'
			alias Lt='L --tree'
		else
			alias ls='ls --almost-all --group-directories-first --color=always'
			alias L='ls -l'
			alias Lt='L --recursive'
		fi
		app_available pls && alias Lp='pls --det perm --det oct --det user --det group --det mtime --det git --det size --header false'
		alias M='mkdir --parents'
		app_available cargo && alias N='cargo new'
		app_available cargo && alias O=''
		alias P='project_info'
		alias Ps='project_info --size'
		app_available cargo && alias Q='cargo watch --quiet --clear --exec "run --quiet --"'
		app_available cargo && alias R='cargo run --release'
		app_available cargo && alias S='cargo search'
		alias T='create_file'
		alias U='project_update'
		app_available code && alias V='code "$PRJ_ROOT"'
		app_available cargo && alias W='cargo watch --quiet --clear --exec "run --"'
		app_available cargo && alias X='project_clean --reset'
		if [ -f "$PRJ_INFO" ]; then
			alias Y='cat "$PRJ_INFO"'
		else
			alias Y='project_info'
		fi
		alias Z='tokei'

		print_heading "Aliases"
		print_block "$(alias | grep "alias [A-Z]=")"
	}

	size_check() {
		print_heading "Storage Utilization"
		if app_available dust; then
			dust --reverse
		else
			du
		fi
	}

	utilities() {
		print_heading "Utilities"
		print_block "$(
			apps="cargo code dust hx just rustc tokei treefmt"
			for app in $apps; do
				if app_available "$app"; then
					print_status --success --app "$app"
				else
					print_status --failure --app "$app"
				fi
			done
		)"
	}

	variables || return "$?"
	utilities
	aliases
	case "$1" in --size | --detailed) size_check ;; esac
}

project_init() {
	print_heading "Project"
	app_available cargo || {
		print_status \
			--error "Initialization failed" \
			--dependency "cargo"
		return 127
	}
	if [ -f Cargo.toml ]; then
		tmp="$(mktemp)"
		file="$PRJ_ROOT/Cargo.toml"
		sed "s|^name = .*|name = \"$PRJ_NAME\"|" "$file" >"$tmp"
		mv -- "$tmp" "$file"
	else
		cargo init --name "$PRJ_NAME"
	fi

	[ -f "$PRJ_ROOT/.cargo/config.toml" ] || {
		mkdir --parents "$PRJ_ROOT/.cargo"
		ln --symbolic \
			"$PRJ_CONF/cargo.toml" \
			"$PRJ_ROOT/.cargo/config.toml"
	}

	cargo build --release
}

project_update() {
	app_available nix && nix flake update
	app_available cargo && cargo update
	app_available geet && geet --push
}

project_git() {
	# Function to initialize a Git repository if not already initialized
	init_repo() {
		# if [ ! -d .git ]; then
		# 	printf "Initializing new Git repository...\n"
		# 	git init
		# else
		# 	printf "Git repository already initialized.\n"
		# fi

		[ ! -d .git ] && {
			print_status "Initializing new Git repository..."
		}
	}

	# Function to add changes to the staging area
	add_changes() {
		printf "Adding changes to the staging area...\n"
		git add .
	}

	# Function to commit changes with a provided message or a default one
	commit_changes() {
		# Join all remaining arguments as the commit message
		COMMIT_MSG="$*"
		if [ -z "$COMMIT_MSG" ]; then
			COMMIT_MSG="Auto-commit"
		fi
		printf "Committing changes with message: '%s'\n" "$COMMIT_MSG"
		git commit -m "$COMMIT_MSG"
	}

	# Function to pull from the remote repository
	pull_changes() {
		printf "Pulling latest changes from remote...\n"
		git pull
	}

	# Function to push changes to the remote repository
	push_changes() {
		printf "Pushing changes to remote...\n"
		git push
	}

	# Main workflow
	init_repo

	# Check if a remote is configured
	if [ "$(git remote get-url origin >/dev/null 2>&1)" ]; then
		if [ "$(git status --porcelain >/dev/null 2>&1)" ]; then
			printf "Local changes detected. Please commit or stash your changes before pulling.\n"
			# TODO: List changes and give a prompt to continue
			return 1
		else
			pull_changes
		fi

		add_changes
		commit_changes "$@"
		push_changes
	else
		add_changes
		commit_changes "$@"
		printf "No remote repository configured. Skipping pull and push.\n"
	fi
}

project_format() {
	app_available treefmt &&
		treefmt \
			--tree-root="$PRJ_ROOT" \
			--config-file "$PRJ_CONF/treefmt.toml" \
			--allow-missing-formatter \
			--ci

	app_available just && just --fmt --quiet
}

project_clean() {
	garbage=""
	case "$1" in
	-x | --reset)
		garbage="
			.git
			.cargo
			Cargo.toml
			Cargo.lock
			src
			.direnv
			target
		"
		;;
	*)
		garbage=".direnv"
		app_available cargo && cargo clean
		;;
	esac

	delete() {
		if app_available trash; then
			trash put "$1"
		else
			rm -rf "$1"
		fi
	}

	for item in $garbage; do
		path="$PRJ_ROOT/$item"
		[ -e "$path" ] && delete "$path"
	done
}

main() {
	helpers_init
	project_info || return "$?"
	project_init || return "$?"
	# If project_info fails, main will immediately exit with the same status code.
	#
	# If project_init fails, main will immediately exit with the same status code.
} && main "$@"
