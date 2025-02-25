#!/bin/sh

main() {
	#@ Uninitialized variables and exit if any occurs
	set -eu

	#@ Initialize the script
	set_defaults
	initialize_output
	initialize_utilities

	#@ Initialize the project
	project_info || return $?
	project_init || return $?
}

set_defaults() {
	debug=0
	ICON_MODE=3
}

initialize_output() {
	TERM_LEVEL=0
	#@ Check basic terminal functionality
	if [ -t 1 ] && [ -z "${NO_COLOR+x}" ] && [ "$TERM" != "linux" ]; then
		TERM_LEVEL=1

		#@ Check Unicode support
		if printf '\u2714' | grep -q "^[[:print:]]*$" 2>/dev/null; then
			TERM_LEVEL=2

			#@ Check full Unicode/Emoji support
			if printf '\U1F7E2' | grep -q "^[[:print:]]*$" 2>/dev/null; then
				TERM_LEVEL=3
			fi
		fi
	fi
	[ ${DEBUG:-0} -eq 1 2>/dev/null ] && printf "Terminal Level: %s\n" "$TERM_LEVEL"

	#@ Set Formatting
	if [ "${TERM_LEVEL:-0}" -gt 0 ]; then

		#@ Cache ANSI fallbacks
		FMT_RED='\033[31m'
		FMT_GREEN='\033[32m'
		FMT_YELLOW='\033[33m'
		FMT_BLUE='\033[34m'
		FMT_PURPLE='\033[35m'
		FMT_CYAN='\033[36m'
		FMT_WHITE='\033[37m'
		FMT_BOLD='\033[1m'
		FMT_ITALIC='\033[3m'
		FMT_UNDERLINE='\033[4m'
		FMT_RESET='\033[0m'

		#@ Cache tput values, if available
		if
			command -v tput >/dev/null 2>&1 &&
				tput init >/dev/null 2>&1
		then
			FMT_RED=$(tput setaf 1)
			FMT_GREEN=$(tput setaf 2)
			FMT_YELLOW=$(tput setaf 3)
			FMT_BLUE=$(tput setaf 4)
			FMT_PURPLE=$(tput setaf 5)
			FMT_CYAN=$(tput setaf 6)
			FMT_WHITE=$(tput setaf 7)
			FMT_BOLD=$(tput bold)
			FMT_ITALIC=$(tput sitm)
			FMT_UNDERLINE=$(tput smul)
			FMT_RESET=$(tput sgr0)
		fi
	else
		#@ Set Blank so that it doesn't print or throw errors
		FMT_RED=''
		FMT_GREEN=''
		FMT_YELLOW=''
		FMT_BLUE=''
		FMT_PURPLE=''
		FMT_CYAN=''
		FMT_WHITE=''
		FMT_BOLD=''
		FMT_ITALIC=''
		FMT_UNDERLINE=''
		FMT_RESET=''
	fi

	#@ Composite styles
	FMT_SUCCESS="${FMT_RESET}${FMT_BOLD}${FMT_GREEN}"
	FMT_FAILURE="${FMT_RESET}${FMT_BOLD}${FMT_RED}"
	FMT_INFO="${FMT_RESET}${FMT_BOLD}${FMT_BLUE}"
	FMT_WARNING="${FMT_RESET}${FMT_BOLD}${FMT_YELLOW}"
	FMT_DEBUG="${FMT_RESET}${FMT_BOLD}${FMT_PURPLE}"
	FMT_HIGHLIGHT="${FMT_RESET}${FMT_BOLD}${FMT_UNDERLINE}"
	FMT_EMPHASIS="${FMT_RESET}${FMT_BOLD}${FMT_ITALIC}"

	#@ Export all FMT_ variables
	export FMT_RED FMT_GREEN FMT_YELLOW FMT_BLUE FMT_PURPLE FMT_CYAN FMT_WHITE
	export FMT_BOLD FMT_ITALIC FMT_UNDERLINE FMT_RESET
	export FMT_SUCCESS FMT_FAILURE FMT_INFO FMT_WARNING FMT_DEBUG FMT_HIGHLIGHT FMT_EMPHASIS

	#@ Set icons based on terminal capabilities and user preference
	ICON_MODE="${ICON_MODE:-$TERM_LEVEL}" # Default to TERM_LEVEL if not set

	#@ Use lower value between ICON_MODE and TERM_LEVEL
	[ "$ICON_MODE" -gt "$TERM_LEVEL" ] && ICON_MODE=$TERM_LEVEL

	#@ Set default icons
	case ${ICON_MODE:-TERM_LEVEL} in
	3) #| Full Unicode/Emoji
		ICON_SUCCESS="🟢"
		ICON_FAILURE="🔴"
		ICON_INFORMATION="ℹ️"
		ICON_WARNING="💡"
		ICON_DEBUG="🔍"
		ICON_ERROR="❌"
		ICON_PADDING=" "
		;;
	2) #| ANSI/Unicode
		ICON_SUCCESS="[✓]"
		ICON_FAILURE="[✗]"
		ICON_INFORMATION="[i]"
		ICON_WARNING="[!]"
		ICON_DEBUG="[◆]"
		ICON_ERROR="[×]"
		ICON_PADDING=" "
		;;
	1) #| Basic ASCII
		ICON_SUCCESS="[+]"
		ICON_FAILURE="[-]"
		ICON_INFORMATION="[i]"
		ICON_WARNING="[!]"
		ICON_DEBUG="[?]"
		ICON_ERROR="[x]"
		ICON_PADDING=" "
		;;
	0) #| No icons
		ICON_SUCCESS=""
		ICON_FAILURE=""
		ICON_INFORMATION=""
		ICON_WARNING=""
		ICON_DEBUG=""
		ICON_ERROR=""
		ICON_PADDING=""
		;;
	esac

	#@ Color Icons, if available
	ICON_SUCCESS="${ICON_PADDING}${FMT_GREEN}${ICON_SUCCESS}${FMT_RESET}${ICON_PADDING}"
	ICON_FAILURE="${ICON_PADDING}${FMT_RED}${ICON_FAILURE}${FMT_RESET}${ICON_PADDING}"
	ICON_INFORMATION="${ICON_PADDING}${FMT_BLUE}${ICON_INFORMATION}${FMT_RESET}${ICON_PADDING}"
	ICON_WARNING="${ICON_PADDING}${FMT_YELLOW}${ICON_WARNING}${FMT_RESET}${ICON_PADDING}"
	ICON_DEBUG="${ICON_PADDING}${FMT_PURPLE}${ICON_DEBUG}${FMT_RESET}${ICON_PADDING}"
	ICON_ERROR="${ICON_PADDING}${FMT_RED}${ICON_ERROR}${FMT_RESET}${ICON_PADDING}"

	#@ Export all ICON_ variables
	export ICON_SUCCESS ICON_FAILURE ICON_INFORMATION ICON_WARNING ICON_DEBUG ICON_ERROR ICON_PADDING

	[ ${DEBUG:-0} -eq 1 2>/dev/null ] && {
		printf "%s: %s\n" "ICON_SUCCESS" "$ICON_SUCCESS"
		printf "%s: %s\n" "ICON_FAILURE" "$ICON_FAILURE"
		printf "%s: %s\n" "ICON_INFORMATION" "$ICON_INFORMATION"
		printf "%s: %s\n" "ICON_WARNING" "$ICON_WARNING"
		printf "%s: %s\n" "ICON_DEBUG" "$ICON_DEBUG"
		printf "%s: %s\n" "ICON_ERROR" "$ICON_ERROR"
	}

	# pout_status() {
	# 	#DOC Print the status of an operation with optional icons and messages.
	# 	#DOC
	# 	#DOC This function accepts the following options:
	# 	#DOC   --success   : Display a success icon.
	# 	#DOC   --failure   : Display a failure icon.
	# 	#DOC   --app       : Specify the application name to display.
	# 	#DOC   --dependency: Specify a missing dependency to display an error.
	# 	#DOC   --error     : Specify an error message to display.
	# 	#DOC
	# 	#DOC Icons and messages are printed with formatting based on the terminal's capabilities.
	# 	#DOC If provided, the application name, missing dependency, or error message is printed.
	# 	#DOC The function ensures that all temporary variables are unset after execution.

	# 	#@ Initialize variables
	# 	status_of="" val=""

	# 	#@ Parse arguments
	# 	while [ "$#" -gt 0 ]; do
	# 		case "$1" in
	# 		--success) icon="$ICON_SUCCESS" ;;
	# 		--failure) icon="$ICON_FAILURE" ;;
	# 		--type) [ "$2" ] && status_of="$2" && shift ;;
	# 		--app) status_of="app" ;;
	# 		--dependency) status_of="dep" ;;
	# 		--error) status_of="err" ;;
	# 		*) val=$1 ;;
	# 		esac
	# 		shift
	# 	done

	# 	#@ Print the status
	# 	case "$status_of" in
	# 	app)
	# 		# Check if the CMD variable for this app exists and is non-empty
	# 		eval "cmd_path=\$CMD_$(printf "%s" "$val" | tr '[:lower:]' '[:upper:]')"
	# 		if [ -n "${cmd_path-}" ]; then
	# 			printf "%s%s -> %s\n" "$ICON_SUCCESS" "$val" "$cmd_path"
	# 		else
	# 			printf "%s%s\n" "$ICON_FAILURE" "$val"
	# 		fi
	# 		;;
	# 	dep)
	# 		printf "%sMissing dependency: %s\n" "$ICON_ERROR" "$val" >&2
	# 		;;
	# 	err)
	# 		printf "%sERROR: %s\n" "$ICON_FAILURE" "$val" >&2
	# 		;;
	# 	*)
	# 		printf "%s%s\n" "$icon" "$val"
	# 		;;
	# 	esac

	# 	#@ Reset variables
	# 	unset status_of
	# }

	pout_status() {
		#@ Initialize variables
		status_of="" val=""

		#@ Parse arguments
		while [ "$#" -gt 0 ]; do
			case "$1" in
			--success) icon="$ICON_SUCCESS" ;;
			--failure) icon="$ICON_FAILURE" ;;
			--error)
				icon="$ICON_FAILURE"
				status_of="error"
				val="$2"
				shift
				;;
			--dependency)
				icon="$ICON_ERROR"
				status_of="dep"
				val="$2"
				shift
				;;
			*) val="$1" ;;
			esac
			shift
		done

		#@ Print based on status type
		case "$status_of" in
		dep)
			printf "%sMissing dependency: %s\n" "$icon" "$val" >&2
			;;
		error)
			printf "%sERROR: %s\n" "$icon" "$val" >&2
			;;
		*)
			printf "%s%s\n" "$icon" "$val"
			;;
		esac
	}
	pout_header() {
		#DOC Print a heading with a title.
		#DOC
		#DOC The heading is printed with a highlighted color and the title is centered.
		#DOC The heading is enclosed in '|>' and '<|' delimiters.
		printf "\n%s|> %s <|%s\n" "$FMT_HIGHLIGHT" "$*" "$FMT_RESET"
	}

	pout_env() {
		#@ Set default widths
		margin=2      # Left margin
		name_width=16 # Name column width
		sep_width=4   # Separator padding
		val_margin=4  # Value left margin
		sep='/>'      # Separator string
		icon=""       # Status icon
		pattern=""    # Alias pattern

		#@ Local helper function
		format_and_print() {
			[ "$#" -lt 2 ] && return
			name="$1"
			val="$2"

			#@ Format with escapes
			fmt_name="${FMT_BOLD}${name}${FMT_RESET}"
			fmt_sep="${FMT_ITALIC}${sep}${FMT_RESET}"
			fmt_val="${FMT_ITALIC}${val}${FMT_RESET}"

			#@ Calculate ANSI adjustments
			name_adj=$((${#FMT_BOLD} + ${#FMT_RESET}))
			sep_adj=$((${#FMT_ITALIC} + ${#FMT_RESET}))

			#@ Print with padding
			printf "%${margin}s%s%-*s%*s%*s%s\n" \
				"" \
				"${icon}" \
				"$((name_width + name_adj))" "$fmt_name" \
				"$((sep_width + sep_adj))" "$fmt_sep" \
				"$val_margin" "" \
				"$fmt_val"
		}

		#@ Process flags
		case "${1-}" in
		--app)
			case "$ICON_MODE" in
			0) margin=2 sep_width=4 ;;
			*) margin=0 sep_width=2 ;;
			esac
			# name_width=8
			# val_margin=2
			shift
			name="$1"
			eval "val=\"\$CMD_$(printf "%s" "$name" | tr '[:lower:]' '[:upper:]')\""
			if [ -n "${val-}" ]; then
				icon="$ICON_SUCCESS"
			else
				icon="$ICON_FAILURE"
				val="Not found"
			fi
			format_and_print "$name" "$val"
			;;
		--compact)
			margin=1
			name_width=8
			sep_width=2
			val_margin=2
			shift
			;;
		--alias)
			pattern='^alias'
			shift
			;;
		--alias-az)
			margin=6
			name_width=1
			sep_width=15
			# val_margin=0
			pattern='^alias [A-Z]='
			shift
			;;
		esac

		#@ Handle aliases if requested
		if [ -n "${pattern-}" ]; then
			names=$(alias | grep "$pattern" | cut -d'=' -f1 | cut -d' ' -f2)
			for name in $names; do
				val="$(alias "$name" | cut -d'=' -f2- | sed "s/^'//;s/'$//")"
				[ -n "$val" ] && format_and_print "$name" "$val"
			done
		else
			#@ Handle variables
			for var; do
				eval "val=\"\${$var-}\""
				[ -n "$val" ] && format_and_print "$var" "$val"
			done
		fi
	}
}

initialize_utilities() {

	cmd_available() {
		command -v "$1" >/dev/null 2>&1
	}

	git_has_changes() {
		[ -n "$(git status --porcelain 2>/dev/null)" ]
	}

	git_has_remote() {
		git remote get-url origin >/dev/null 2>&1
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
			pout_status --error "Failed to determine the project root (either a Flake or Git repository)"
			return 2
		fi
	}

	create_file() {
		while [ "$#" -ge 1 ]; do

			#@ Create the parent directory if it doesn't exist
			case "$1" in
			*/*) mkdir -p "$(dirname "$1")" ;;
			esac

			#@ Create the file
			touch "$1"

			#@ Shift to the next argument
			shift
		done
	}

	find_first() {
		search_root="$PRJ_ROOT"
		search_depth=2
		search_type="file"

		while [ "$#" -ge 1 ]; do
			case "$1" in
			--path | --root) [ "$2" ] && search_root=$2 ;;
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

	timestamp() {
		date '+%Y%m%d_%H%M%S'
	}

	size_check() {
		pout_header "Storage Utilization"
		if [ "$CMD_DUST" ]; then
			dust --reverse
		else
			du
		fi
	}

	fastfetch_wrapper() {
		[ "$CMD_FASTFETCH" ] || return
		FASTFETCH_CONFIG="${FASTFETCH_CONFIG:-$1}"

		pretty_os_print() {
			[ -z "$CMD_FIGLET" ] || [ -z "$CMD_JQ" ] || return
			figlet -f slant "$(
				fastfetch -s os --format json | jq -r '.[0].result.name'
			)"
		}

		fastfetch_cmd() {
			if [ -n "$FASTFETCH_CONFIG" ]; then
				pretty_os_print
				fastfetch --config "$FASTFETCH_CONFIG"
			else
				pretty_os_print
				fastfetch
			fi
		}

		fastfetch_cmd "$@"
	}

	helix_wrapper() {
		[ "$CMD_HELIX" ] || return

		#@ Initialize variables
		helix_cmd="hx"
		helix_root="$PRJ_ROOT"
		helix_conf="${HELIX_CONF:-$PRJ_ROOT/.config/helix.toml}"
		helix_log="${HELIX_LOG:-$PRJ_ROOT/.cache/helix.log}"
		helix_flags=""
		helix_args=""

		while [ "$#" -ge 1 ]; do
			case "$1" in
			--config) [ "$2" ] && helix_conf="$2" ;;
			--root) [ "$2" ] && helix_root="$2" ;;
			--log) [ "$2" ] && helix_log="$2" ;;
			--flag) helix_flags="${helix_flags}${helix_flags:+ }${2}" ;;
			--)
				shift
				helix_args="${helix_args}${helix_args:+ }${2}"
				;;

			*)
				helix_args="${helix_args}${helix_args:+ }${1}"
				;;
			esac
			shift
		done

		[ "$helix_flags" ] && helix_cmd="${helix_cmd} ${helix_flags}"
		[ "$helix_conf" ] && helix_cmd="${helix_cmd} --config ${helix_conf}"
		[ "$helix_root" ] && helix_cmd="${helix_cmd} --working-dir ${helix_root}"
		[ "$helix_log" ] && helix_cmd="${helix_cmd} --log ${helix_log}"

		$helix_cmd "${helix_args:-$helix_root}"
	}
}

project_info() {
	define_utilities() {
		pout_header "Utilities"

		UTILITIES="
			cargo
			code
			direnv
			dotsrus
			dust
			fastfetch
			git
			hx
			just
			mktemp
			rustc
			starship
			thefuck
			tokei
			pop
			treefmt
			zoxide
		"

		for dependency in $UTILITIES; do
			#@ Define	the variable name in uppercase
			var="$(printf "CMD_%s" "$dependency" | tr '[:lower:]' '[:upper:]')"

			#@ Get the absolute path of the dependency
			val="$(command -v "$dependency")"

			#@ Export the variable
			eval "$var"="$val"
			export var

			#@ Print the status and export the valid ones
			pout_env --app "$dependency"
		done
	}

	define_variables() {
		pout_header "Variables"

		#| Project
		PRJ_ROOT=$(pathof_flake_or_git)
		PRJ_NAME="$(
			basename "$PRJ_ROOT" |
				sed -e 's/[^[:alnum:]]/_/g' \
					-e 's/__*/_/g' \
					-e 's/^_//' \
					-e 's/_$//' |
				tr '[:upper:]' '[:lower:]'
		)"
		PRJ_BCUP="$PRJ_ROOT/.archive"
		PRJ_CACHE="$PRJ_ROOT/.cache"
		PRJ_CONF="$(dirname "$(find_first --root "$PRJ_ROOT" --target "init*")")"
		PRJ_INFO="$(find_first --root "$PRJ_ROOT" --target "readme*")"
		export PRJ_ROOT PRJ_NAME PRJ_CONF PRJ_INFO PRJ_BCUP
		pout_env PRJ_NAME PRJ_ROOT PRJ_CONF PRJ_INFO PRJ_BCUP

		#| Direnv
		if [ "$CMD_DIRENV" ]; then
			DIRENV_LOG_FORMAT=""
			export DIRENV_LOG_FORMAT
			pout_env DIRENV_LOG_FORMAT
		fi

		#| Helix
		[ "$CMD_HX" ] && {
			HELIX_CONFIG="$PRJ_CONF/helix.toml"
			HELIX_LANG="$PRJ_CONF/languages.toml"
			HELIX_LOG="$PRJ_CACHE/helix.log"
			export HELIX_CONFIG HELIX_LANG HELIX_LOG
			pout_env HELIX_CONFIG HELIX_LANG HELIX_LOG
		}

		#| Just
		[ "$CMD_JUST" ] && {
			JUST_JUSTFILE="$(find_first --root "$PRJ_ROOT" --target "justfile")"
			JUST_UNSTABLE=true
			export JUST_JUSTFILE JUST_UNSTABLE
			pout_env JUST_JUSTFILE JUST_UNSTABLE
		}

		#| Fastfetch
		[ "$CMD_FASTFETCH" ] && {
			FASTFETCH_CONFIG="$PRJ_CONF/fastfetch.jsonc"
			export FASTFETCH_CONFIG
			pout_env FASTFETCH_CONFIG
		}

		#| Starship
		[ "$CMD_STARSHIP" ] && {
			STARSHIP_CONFIG="$PRJ_CONF/starship.toml"
			export STARSHIP_CONFIG
			pout_env STARSHIP_CONFIG
		}
	}

	define_aliases() {
		cmd_available bat && alias cat='bat --style=plain'
		cmd_available cargo && alias A='cargo add'
		alias B='project_build'
		cmd_available cargo && alias C='project_clean'
		cmd_available dust && alias D='cargo remove'
		cmd_available hx && alias E='hx'
		alias F='project_format'
		cmd_available cargo && alias G='cargo generate'
		cmd_available hx && alias H='hx "$PRJ_ROOT"'
		alias I='project_init'
		cmd_available just && alias J='just'
		alias K='exit'
		if cmd_available eza; then
			alias ls='eza --almost-all --group-directories-first --color=always --icons=always --git --git-ignore --time-style relative --total-size --smart-group'
			alias L='ls --long '
			alias La='ls --long --git'
			alias Lt='L --tree'
		elif cmd_available lsd; then
			alias ls='lsd --almost-all --group-directories-first --color=always'
			alias L='ls --long --git --date=relative --versionsort --total-size'
			alias Lt='L --tree'
		else
			alias ls='ls --almost-all --group-directories-first --color=always'
			alias L='ls -l'
			alias Lt='L --recursive'
		fi
		cmd_available pls && alias Lp='pls --det perm --det oct --det user --det group --det mtime --det git --det size --header false'
		alias M='mkdir --parents'
		cmd_available cargo && alias N='cargo new'
		cmd_available cargo && alias O=''
		alias P='project_info'
		alias Ps='project_info --size'
		cmd_available cargo && alias Q='cargo watch --quiet --clear --exec "run --quiet --"'
		cmd_available cargo && alias R='cargo run --release'
		cmd_available cargo && alias S='cargo search'
		alias T='create_file'
		alias U='project_update'
		cmd_available code && alias V='code "$PRJ_ROOT"'
		cmd_available cargo && alias W='cargo watch --quiet --clear --exec "run --"'
		cmd_available cargo && alias X='project_clean --reset'
		if [ -f "$PRJ_INFO" ]; then
			alias Y='cat "$PRJ_INFO"'
		else
			alias Y='project_info'
		fi
		alias Z='tokei'

		pout_header "Aliases"
		pout_env --alias-az
	}

	define_utilities
	define_variables
	define_aliases
}

project_init() {

	pout_header "Project"

	init_cargo() {
		#@ Verify cargo is available
		cmd_available cargo || {
			pout_status \
				--error "Initialization failed" \
				--dependency "cargo"
			return 127
		}

		#@ Set up temporary file handling
		if [ "$CMD_MKTEMP" ]; then
			tmp="$(mktemp)" || exit 1
		else
			tmp="${TMPDIR:-/tmp}/${0##*/}.$$.tmp"
		fi
		trap 'rm -f "$tmp"' EXIT

		#@ Create/Update Cargo.toml with project name
		if [ -f Cargo.toml ]; then
			#@ Update existing Cargo.toml
			file="$PRJ_ROOT/Cargo.toml"
			sed "s|^name = .*|name = \"$PRJ_NAME\"|" "$file" >"$tmp"
			mv -- "$tmp" "$file"
		else
			#@ Initialize new Cargo project
			cargo init --name "$PRJ_NAME"
		fi

		#@ Define config paths
		config_toml_src="$PRJ_CONF/cargo.toml"
		config_toml_lnk="$PRJ_ROOT/.cargo/config.toml"
		config_toml_bac="$PRJ_BCUP/.cargo/.archive/config.toml.$(timestamp)"

		#@ Create config directories
		mkdir -p "$(dirname "$config_toml_lnk")"

		#@ Debug helper function
		debug_config() {
			[ ${DEBUG:-0} -eq 1 2>/dev/null ] || return 0
			printf "Target exists: %s\n" "$([ -e "$1" ] && echo "yes" || echo "no")"
			printf "Is symlink: %s\n" "$([ -L "$1" ] && echo "yes" || echo "no")"
			printf "Is file: %s\n" "$([ -f "$1" ] && echo "yes" || echo "no")"
			printf "Target path: %s\n" "$(readlink -f "$1" 2>/dev/null || echo "none")"
		}

		#@ Backup helper function
		backup_config() {
			backup_dir="$(dirname "$config_toml_bac")"
			mkdir -p "$backup_dir"
			cp -p "$1" "$config_toml_bac"

			#@ Rotate backups (keep last 5)
			find "${backup_dir}" -maxdepth 1 -type f -name "config.toml.*" -printf '%T@ %p\n' |
				sort -rn |
				awk 'NR>5 {sub(/^[^ ]+ /, ""); print}' |
				xargs -r rm --
		}

		#@ Sync config files
		debug_config "$config_toml_lnk"

		if [ -e "$config_toml_lnk" ]; then
			#@ Target exists
			if [ -L "$config_toml_lnk" ]; then
				#@ Is symlink - backup and remove
				backup_config "$config_toml_lnk"
				unlink "$config_toml_lnk"
				cp "$config_toml_src" "$config_toml_lnk"
			elif [ -f "$config_toml_lnk" ]; then
				if [ "$(find "$config_toml_src" -prune -newer "$config_toml_lnk" 2>/dev/null)" ]; then
					#@ Source is newer - backup target and update
					backup_config "$config_toml_lnk"
					rm -f "$config_toml_lnk"
					cp "$config_toml_src" "$config_toml_lnk"
				elif [ "$(find "$config_toml_lnk" -prune -newer "$config_toml_src" 2>/dev/null)" ]; then
					#@ Target is newer - backup source and update
					backup_config "$config_toml_src"
					rm -f "$config_toml_src"
					cp "$config_toml_lnk" "$config_toml_src"
				fi
			fi
		else
			#@ Target doesn't exist - copy from source
			cp "$config_toml_src" "$config_toml_lnk"
		fi
	}

	#@ Initialize Cargo project
	init_cargo

	# cmd_available cargo || {
	# 	pout_status \
	# 		--error "Initialization failed" \
	# 		--dependency "cargo"
	# 	return 127
	# }

	# #@ Create/Update Cargo.toml with the project name
	# if [ -f Cargo.toml ]; then
	# 	if command -v mktemp >/dev/null 2>&1; then
	# 		tmp="$(mktemp)" || exit 1
	# 	else
	# 		tmp="${TMPDIR:-/tmp}/${0##*/}.$$.tmp"
	# 	fi
	# 	trap 'rm -f "$tmp"' EXIT

	# 	file="$PRJ_ROOT/Cargo.toml"
	# 	sed "s|^name = .*|name = \"$PRJ_NAME\"|" "$file" >"$tmp"
	# 	mv -- "$tmp" "$file"
	# else
	# 	cargo init --name "$PRJ_NAME"
	# fi

	# config_toml_lnk="$PRJ_ROOT/.cargo/config.toml"
	# config_toml_src="$PRJ_CONF/cargo.toml"
	# config_toml_bac="$PRJ_BCUP/.cargo/.archive/config.toml.$(timestamp)"

	# #@ Ensure the target parent directory exists
	# mkdir -p "$(dirname "$config_toml_lnk")"

	# #@ Create backup if target exists
	# [ -f "$config_toml_lnk" ] && {

	# 	#@ Create backup
	# 	backup_dir="$(dirname "$config_toml_bac")"
	# 	mkdir -p "$backup_dir"
	# 	cp -p "$config_toml_lnk" "$config_toml_bac"

	# 	#@ Cleanup old backups (keep last 3)
	# 	find "${backup_dir}" -maxdepth 1 -type f -name "config.toml.*" -printf '%T@ %p\n' |
	# 		sort -rn |
	# 		awk 'NR>5 {sub(/^[^ ]+ /, ""); print}' |
	# 		xargs -r rm --
	# }

	# if [ ! -f "$config_toml_lnk" ] || [ -L "$config_toml_src" ] ||
	# [ "$(find "$config_toml_src" -prune -newer "$config_toml_lnk" 2>/dev/null)" ]; then
	# 	rm -f "$config_toml_lnk"
	# 	cp "$config_toml_src" "$config_toml_lnk"
	# elif [ "$(find "$config_toml_lnk" -prune -newer "$config_toml_src" 2>/dev/null)" ]; then
	# 	cp "$config_toml_src" "$config_toml_bac"
	# 	rm -f "$config_toml_src"
	# 	cp "$config_toml_lnk" "$config_toml_src"
	# fi

	project_build
}

project_build() {
	cmd_available cargo || {
		pout_status \
			--error "Build failed" \
			--dependency "cargo"
		return 127
	}
	cargo build --release
	cargo install --path "$PRJ_ROOT"
}

project_update() {
	cmd_available nix && nix flake update
	cmd_available cargo && cargo update
	cmd_available geet && geet --push
}

project_git() {
	#@ Initialize if needed
	[ ! -d .git ] && {
		pout_status "Initializing Git repository..."
		git init
	}

	#@ Check for changes first
	if git_has_changes; then
		git add .
		git commit -m "${*:-Auto-commit}"
	fi

	#@ Handle remote operations
	if git_has_remote; then
		if git_has_changes; then
			pout_status "Local changes detected. Commit or stash before pulling."
			return 1
		fi
		git pull && git push
	fi
}

project_git_old() {
	# Function to initialize a Git repository if not already initialized
	init_repo() {
		# if [ ! -d .git ]; then
		# 	printf "Initializing new Git repository...\n"
		# 	git init
		# else
		# 	printf "Git repository already initialized.\n"
		# fi

		[ ! -d .git ] && {
			pout_status "Initializing new Git repository..."
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
	cmd_available treefmt &&
		treefmt \
			--tree-root="$PRJ_ROOT" \
			--config-file "$PRJ_CONF/treefmt.toml" \
			--allow-missing-formatter \
			--ci

	cmd_available just && just --fmt --quiet
}

project_clean() {
	cleanup_paths=""
	case "${1:-}" in
	-x | --reset)
		cleanup_paths=".git .cargo Cargo.toml Cargo.lock src .direnv target"
		;;
	*)
		cleanup_paths=".direnv"
		cmd_available cargo && cargo clean
		;;
	esac

	#@ Save and set IFS
	old_ifs="$IFS"
	IFS=' '

	#@ Remove files safely with proper quoting
	for item in $cleanup_paths; do
		target="${PRJ_ROOT:?}/${item}"
		[ -e "$target" ] && {
			if cmd_available trash; then
				trash put -- "$target"
			else
				rm -rf -- "$target"
			fi
		}
	done

	#@ Restore IFS
	IFS="$old_ifs"
}

main "$@"
