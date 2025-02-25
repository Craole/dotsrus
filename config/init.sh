#!/bin/sh

main() {
	#@ Initialize the script
	initialize_defaults
	initialize_output_mode
	initialize_functions

	#@ Initialize the project
	project_info || return "$?"
	project_init || return "$?"
}

initialize_defaults() {
	verbosity="info"  #? 0: quiet, 1: error, 2: warn, 3: info, 4: debug, 5: trace
	color_mode="auto" #? 0: none, 1|auto: ansi/tput
	icon_mode="auto"  #? 0: none, 1: ascii, 2: unicode, 3: emoji
}

initialize_output_mode() {
	detect_terminal_capabilities() {
		#@ Define helper to check for printable characters
		can_print() {
			LC_ALL=C
			grep -q "^[[:print:]]*$" 2>/dev/null
		}

		#@ Check terminal capabilities
		TERM_LEVEL=0
		if printf '%s' '\U1F7E2' | can_print; then
			TERM_LEVEL=3 #? Full Unicode/Emoji
		elif printf '%s' '\u2714' | can_print; then
			TERM_LEVEL=2 #? Basic Unicode
		elif printf '%s' 'X' | can_print; then
			TERM_LEVEL=1 #? ASCII only
		fi

		#@ Check terminal color support
		TERM_COLOR_SUPPORTED=0
		case "${TERM:-}" in
		*-m | dumb) ;;
		*)
			if [ -z "${NO_COLOR+x}" ] && [ -t 1 ]; then
				TERM_COLOR_SUPPORTED=1
			fi
			;;
		esac

		#@ Check for tput support
		TERM_COLORS=8
		if command -v tput >/dev/null 2>&1; then
			if tput init >/dev/null 2>&1; then
				CMD_TPUT="$(command -v tput)"
				TERM_COLORS="$(tput colors 2>/dev/null || printf '%s' 8)"
			fi
		fi

		#@ Set terminal level globally
		export TERM_LEVEL TERM_COLORS TERM_COLOR_SUPPORTED CMD_TPUT
	}

	set_verbosity_level() {
		#@ Define verbosity levels
		VERBOSITY_LEVEL_QUIET=0
		VERBOSITY_LEVEL_ERROR=1
		VERBOSITY_LEVEL_WARN=2
		VERBOSITY_LEVEL_INFO=3
		VERBOSITY_LEVEL_DEBUG=4
		VERBOSITY_LEVEL_TRACE=5

		#@ Set verbosity based on user preference or default
		case "$verbosity" in
		'' | 0 | off | false | quiet) VERBOSITY_LEVEL=$VERBOSITY_LEVEL_QUIET ;;
		1 | on | true | error) VERBOSITY_LEVEL=$VERBOSITY_LEVEL_ERROR ;;
		2 | warn) VERBOSITY_LEVEL=$VERBOSITY_LEVEL_WARN ;;
		3 | info) VERBOSITY_LEVEL=$VERBOSITY_LEVEL_INFO ;;
		4 | debug) VERBOSITY_LEVEL=$VERBOSITY_LEVEL_DEBUG ;;
		5 | trace) VERBOSITY_LEVEL=$VERBOSITY_LEVEL_TRACE ;;
		*)
			if [ "$verbosity" -gt "$VERBOSITY_LEVEL_TRACE" ] >/dev/null 2>&1; then
				VERBOSITY_LEVEL="$VERBOSITY_LEVEL_TRACE"
			elif [ "$verbosity" -lt "$VERBOSITY_LEVEL_QUIET" ] >/dev/null 2>&1; then
				VERBOSITY_LEVEL="$VERBOSITY_LEVEL_QUIET"
			else
				VERBOSITY_LEVEL="$VERBOSITY_LEVEL_INFO"
			fi
			;;
		esac

		#@ Set verbosity levels globally
		export VERBOSITY_LEVEL VERBOSITY_LEVEL_QUIET VERBOSITY_LEVEL_ERROR VERBOSITY_LEVEL_WARN VERBOSITY_LEVEL_INFO VERBOSITY_LEVEL_DEBUG VERBOSITY_LEVEL_TRACE
	}

	set_attributes() {
		#@ Define format attributes
		if [ -n "$CMD_TPUT" ]; then
			FMT_RESET="$(tput sgr0)"
			FMT_BOLD="$(tput bold)"
			FMT_DIM="$(tput dim)"
			FMT_ITALIC="$(tput sitm)"
			FMT_UNDERLINE="$(tput smul)"
			FMT_BLINK="$(tput blink)"
			FMT_INVERT="$(tput rev)"
			FMT_HIDDEN="$(tput invis)"
		else
			FMT_RESET="$(printf '\033[0m')"
			FMT_BOLD="$(printf '\033[1m')"
			FMT_DIM="$(printf '\033[2m')"
			FMT_ITALIC="$(printf '\033[3m')"
			FMT_UNDERLINE="$(printf '\033[4m')"
			FMT_BLINK="$(printf '\033[5m')"
			FMT_INVERT="$(printf '\033[7m')"
			FMT_HIDDEN="$(printf '\033[8m')"
		fi

		#@ Define Presets
		FMT_HIGHLIGHT="${FMT_HIGHLIGHT:-${FMT_BOLD}${FMT_UNDERLINE}}"
		FMT_EMPHASIS="${FMT_EMPHASIS:-${FMT_BOLD}${FMT_ITALIC}}"

		#@ Export format attributes
		export FMT_RESET FMT_BOLD FMT_DIM FMT_ITALIC FMT_UNDERLINE FMT_BLINK FMT_INVERT FMT_HIDDEN FMT_HIGHLIGHT FMT_EMPHASIS
	}

	set_colors() {
		#@ Check color mode and capabilities
		[ -n "${NO_COLOR+x}" ] && return            # Honor NO_COLOR
		[ "$TERM_COLOR_SUPPORTED" -ne 1 ] && return # Need color support

		case "${color_mode:-auto}" in
		'' | null | false | no | 0 | none) return ;; # Explicitly disabled
		*) ;;                                        # Continue with colors
		esac

		#@ Set the basic 8 colors
		base_colors="BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE"
		i=0
		for color in $base_colors; do
			if [ -n "$CMD_TPUT" ]; then
				eval "CLR_FG_${color}=\"\$(tput setaf $i)\""
				eval "CLR_BG_${color}=\"\$(tput setab $i)\""
				eval "export CLR_FG_${color} CLR_BG_${color}"
			else
				eval "CLR_FG_${color}=\$'\\033[3${i}m'"
				eval "CLR_BG_${color}=\$'\\033[4${i}m'"
				eval "export CLR_FG_${color} CLR_BG_${color}"
			fi
			i=$((i + 1))
		done

		#@ Extended colors for 256-color terminals
		if [ "$TERM_COLORS" -ge 256 ]; then
			#| Reds
			CLR_FG_DARKRED="$CLR_FG_RED" CLR_FG_MAROON="$CLR_FG_RED"
			export CLR_FG_DARKRED CLR_FG_MAROON

			#| Yellows
			CLR_FG_GOLD="$CLR_FG_YELLOW" CLR_FG_ORANGE="$CLR_FG_YELLOW"
			export CLR_FG_GOLD CLR_FG_ORANGE

			#| Greens
			CLR_FG_LIME="$CLR_FG_GREEN" CLR_FG_OLIVE="$CLR_FG_GREEN"
			export CLR_FG_LIME CLR_FG_OLIVE

			#| Blues
			CLR_FG_TEAL="$CLR_FG_CYAN" CLR_FG_NAVY="$CLR_FG_BLUE"
			export CLR_FG_TEAL CLR_FG_NAVY

			#| Purples
			CLR_FG_PURPLE="$CLR_FG_MAGENTA" CLR_FG_PINK="$CLR_FG_MAGENTA"
			export CLR_FG_PURPLE CLR_FG_PINK
		fi
	}

	set_icons() {
		#@ Check if icons are disabled globally
		[ -n "${NO_ICONS+x}" ] && return #? Honor NO_ICONS

		#@ Set the icon mode based on preferences and capabilities
		ICON_MODE="${icon_mode:-"$ICON_MODE:-auto}"}"

		#@ Check and update icon mode
		case "$ICON_MODE" in
		0 | none | null | false | no)
			return
			;; #? Explicitly disabled
		1 | 2 | 3)
			[ "$ICON_MODE" -gt "$TERM_LEVEL" ] &&
				ICON_MODE=$TERM_LEVEL #? Clamped to terminal level
			;;
		auto | *)
			ICON_MODE=$TERM_LEVEL
			;; #? Default/auto mode
		esac

		#@ Set the icons
		case $ICON_MODE in
		3) #| Full Unicode/Emoji
			ICON_SUCCESS="${icon_emoji_success:-"🟢"}"
			ICON_FAILURE="${icon_emoji_failure:-"🔴"}"
			ICON_INFORMATION="${icon_emoji_information:-"ℹ️"}"
			ICON_WARNING="${icon_emoji_warning:-"💡"}"
			ICON_DEBUG="${icon_emoji_debug:-"🔍"}"
			ICON_ERROR="${icon_emoji_error:-"❌"}"
			ICON_PADDING="${icon_emoji_padding:-" "}"
			;;
		2) #| ANSI/Unicode
			ICON_SUCCESS="${icon_unicode_success:-"[✓]"}"
			ICON_FAILURE="${icon_unicode_failure:-"[✗]"}"
			ICON_INFORMATION="${icon_unicode_success:-"[i]"}"
			ICON_WARNING="${icon_unicode_information:-"[!]"}"
			ICON_DEBUG="${icon_unicode_warning:-"[◆]"}"
			ICON_ERROR="${icon_unicode_debug:-"[×]"}"
			ICON_PADDING="${icon_unicode_padding:-" "}"
			;;
		1) #| Basic ASCII
			ICON_SUCCESS="${icon_ascii_success:-"[+]"}"
			ICON_FAILURE="${icon_ascii_failure:-"[-]"}"
			ICON_INFORMATION="${icon_ascii_information:-"[i]"}"
			ICON_WARNING="${icon_ascii_warning:-"[!]"}"
			ICON_DEBUG="${icon_ascii_debug:-"[?]"}"
			ICON_ERROR="${icon_ascii_error:-"[x]"}"
			ICON_PADDING="${icon_ascii_success:-" "}"
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
		ICON_SUCCESS="${ICON_PADDING}${CLR_FG_GREEN}${ICON_SUCCESS}${FMT_RESET}${ICON_PADDING}"
		ICON_FAILURE="${ICON_PADDING}${CLR_FG_RED}${ICON_FAILURE}${FMT_RESET}${ICON_PADDING}"
		ICON_INFORMATION="${ICON_PADDING}${CLR_FG_BLUE}${ICON_INFORMATION}${FMT_RESET}${ICON_PADDING}"
		ICON_WARNING="${ICON_PADDING}${CLR_FG_YELLOW}${ICON_WARNING}${FMT_RESET}${ICON_PADDING}"
		ICON_DEBUG="${ICON_PADDING}${CLR_FG_PURPLE}${ICON_DEBUG}${FMT_RESET}${ICON_PADDING}"
		ICON_ERROR="${ICON_PADDING}${CLR_FG_RED}${ICON_ERROR}${FMT_RESET}${ICON_PADDING}"

		#@ Export all ICON_ variables
		export ICON_MODE ICON_SUCCESS ICON_FAILURE ICON_INFORMATION ICON_WARNING ICON_DEBUG ICON_ERROR ICON_PADDING
	}

	#@ Initialize functions
	detect_terminal_capabilities
	set_verbosity_level
	set_attributes
	set_colors
	set_icons
}

initialize_functions() {
	pout_status() {
		#@ Initialize variables
		status_of="" val="" ctx="$PRJ_NAME"

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
			--context)
				context="$2"
				shift
				;;
			*) val="$1" ;;
			esac
			shift
		done

		#@ Print based on status type
		case "$status_of" in
		dep)
			printf "%s%s %s required by the %s%s\n" \
				"$icon" \
				"${CLR_FG_RED}${FMT_HIGHLIGHT}Missing Dependency${FMT_RESET}" \
				"${FMT_EMPHASIS}${val}${FMT_RESET}" \
				"${FMT_BOLD}${context:-$ctx}${FMT_RESET}" \
				"$(
					if [ "$context" ]; then
						printf " function."
					else
						printf " project."
					fi
				)" >&2
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

	check_dependencies() {
		#@ Initialize variables
		# context="the ${PRJ_NAME} project"
		deps=""

		#@ Parse options and collect deps
		while [ "$#" -gt 0 ]; do
			case "$1" in
			--context)
				context="$2" # Override auto-context
				shift
				;;
			*)
				deps="${deps:+$deps }$1"
				;;
			esac
			shift
		done

		#@ Check each dependency
		for dep in $deps; do
			dep_upper=$(printf '%s' "$dep" | tr '[:lower:]' '[:upper:]')
			dep_lower=$(printf '%s' "$dep" | tr '[:upper:]' '[:lower:]')

			eval "[ \"\$CMD_${dep_upper}\" ]" || {
				pout_status \
					--error "Initialization failed" \
					--dependency "$dep_lower" \
					--context "$context"
				return 127
			}
		done
	}

	init_config_file() {
		#@ Required parameters
		src="$1" # Source file
		lnk="$2" # Target link
		bac="$3" # Backup path
		dep="$4" # Required dependency

		#@ Verify dependency if specified
		[ "$dep" ] && ! command -v "$dep" >/dev/null 2>&1 && {
			pout_status \
				--error "Initialization failed" \
				--dependency "$dep"
			return 127
		}

		#@ Verify source exists
		[ ! -f "$src" ] && {
			pout_status --error "Source file missing: $src"
			return 1
		}

		#@ Set up temporary file handling
		if [ "$CMD_MKTEMP" ]; then
			tmp="$(mktemp)" || exit 1
		else
			tmp="${TMPDIR:-/tmp}/${0##*/}.$$.tmp"
		fi
		trap 'rm -f "$tmp"' EXIT

		#@ Create target directories
		mkdir -p "$(dirname "$lnk")"
		mkdir -p "$(dirname "$bac")"
		mkdir -p "$(dirname "$src")"

		#@ Check if target exists
		if [ -e "$lnk" ]; then
			if [ -L "$lnk" ]; then
				#@ Is symlink - backup and remove
				cp "$lnk" "$bac"
				unlink "$lnk"
				cp "$src" "$lnk"
			elif [ -f "$lnk" ]; then
				if [ "$(find "$src" -prune -newer "$lnk" 2>/dev/null)" ]; then
					#@ Source is newer - backup target and update
					cp "$lnk" "$bac"
					rm -f "$lnk"
					cp "$src" "$lnk"
				elif [ "$(find "$lnk" -prune -newer "$src" 2>/dev/null)" ]; then
					#@ Target is newer - backup source and update
					cp "$src" "$bac"
					rm -f "$src"
					cp "$lnk" "$src"
				fi
			fi
		else
			#@ Target doesn't exist - copy from source
			cp "$src" "$lnk"
		fi
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

	editor_wrapper() {
		ide=1
		while [ "$#" -ge 1 ]; do
			case "$1" in
			--visual | --ide | --gui) ide=1 ;;
			*) ;;
			esac
			shift
		done

		if [ "$ide" -eq 1 ]; then
			editor="${EDITOR:-hx}"
		else
			editor="${VISUAL:-hx}"
		fi

		case "$editor" in
		hx) helix_wrapper "$@" ;;
		*) "$editor" "$PRJ_ROOT" ;;
		esac
	}

	helix_wrapper() {
		[ "$CMD_HX" ] || return

		#@ Initialize variables
		helix_cmd="hx"
		helix_root="$PRJ_ROOT"
		helix_conf="${HELIX_CONF:-$PRJ_CONF/helix.toml}"
		helix_log="${HELIX_LOG:-$PRJ_CACHE/helix.log}"
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

		eval "$helix_cmd" "${helix_args:-$helix_root}"
	}

		treefmt_wrapper() {
		check_dependencies treefmt || return $?
		treefmt \
			--config-file "$PRJ_CONF/treefmt.toml" \
			--ci \
			--tree-root "$PRJ_ROOT"
		# --allow-missing-formatter \
	}
}

project_info() {
	define_utilities() {
		pout_header "Utilities"

		UTILITIES="
			bat
			cargo
			code
			direnv
			dotsrus
			dust
			eza
			fd
			fastfetch
			git
			hx
			just
			lsd
			mktemp
			nix
			pls
			rg
			rustc
			starship
			thefuck
			tokei
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
		PRJ_CACHE="$PRJ_ROOT/.cache"
		PRJ_CONF="$(dirname "$(find_first --root "$PRJ_ROOT" --target "init*")")"
		PRJ_INFO="$(find_first --root "$PRJ_ROOT" --target "readme*")"
		export PRJ_ROOT PRJ_NAME PRJ_CONF PRJ_INFO
		pout_env PRJ_NAME PRJ_ROOT PRJ_CONF PRJ_INFO

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
		[ "$CMD_BAT" ] && alias cat='bat --style=plain'
		[ "$CMD_CARGO" ] && alias A='cargo add'
		alias B='project_build'
		[ "$CMD_CARGO" ] && alias C='project_clean'
		[ "$CMD_CARGO" ] && alias D='cargo remove'

		alias E='editor_wrapper'

		alias F='project_format'

		[ "$CMD_CARGO" ] && alias G='cargo generate'

		[ "$CMD_HX" ] && alias H='helix_wrapper' #? Change to help

		alias I='project_init'

		[ "$CMD_JUST" ] && alias J='just'
		alias K='exit'
		if [ "$CMD_EZA" ]; then
			alias L='eza --long --almost-all --group-directories-first --color=always --icons=always --git --git-ignore --time-style relative --total-size --smart-group'
			alias Lt='L --tree'
		elif [ "$CMD_LSD" ]; then
			alias L='lsd --long --almost-all --group-directories-first --color=always --git --date=relative --versionsort --total-size'
			alias Lt='L --tree'
		else
			alias L='ls -lAhF --color=always --group-directories-first'
			alias Lt='L --recursive'
		fi
		[ "$CMD_PLS" ] && alias Lp='pls --det perm --det oct --det user --det group --det mtime --det git --det size --header false'
		alias M='mkdir --parents'
		[ "$CMD_CARGO" ] && alias N='cargo new'
		alias O='size_check'
		alias P='project_info'
		[ "$CMD_CARGO" ] && alias Q='cargo watch --quiet --clear --exec "run --quiet --"'
		[ "$CMD_CARGO" ] && alias R='cargo run --release'
		[ "$CMD_CARGO" ] && alias S='cargo search'
		alias T='create_file'
		alias U='project_update'
		alias V='editor_wrapper --visual'
		[ "$CMD_CARGO" ] && alias W='cargo watch --quiet --clear --exec "run --"'
		alias X='project_clean --reset'

		if [ -f "$PRJ_INFO" ]; then
			if [ "$READER" ]; then
				reader="$READER"
			elif [ "$CMD_BAT" ]; then
				reader='bat'
			else
				reader='cat'
			fi
			alias Y='eval -- \"$reader\" \"$PRJ_INFO\"'
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
		#@ Verify required dependencies
		check_dependencies cargo || return $?

		#@ Set up temporary file
		if command -v mktemp >/dev/null 2>&1; then
			tmp="$(mktemp)" || exit 1
		else
			tmp="${TMPDIR:-/tmp}/${0##*/}.$$.tmp"
		fi
		trap 'rm -f "$tmp"' EXIT

		#@ Update Cargo.toml if it exists
		if [ -f Cargo.toml ]; then
			file="$PRJ_ROOT/Cargo.toml"
			sed "s|^name = .*|name = \"$PRJ_NAME\"|" "$file" >"$tmp"
			mv -- "$tmp" "$file"
		else
			cargo init --name "$PRJ_NAME"
		fi

		#@ Initialize cargo config
		init_config_file \
			"$PRJ_CONF/cargo.toml" \
			"$PRJ_ROOT/.cargo/config.toml" \
			"$PRJ_CACHE/config.toml.$(timestamp)" \
			"cargo"
	}

	init_gitignore() {
		#@ Verify required dependencies
		check_dependencies git --context init_gitignore || return $?

		#@ Initialize gitignore
		init_config_file \
			"$PRJ_CONF/.gitignore" \
			"$PRJ_ROOT/.gitignore" \
			"$PRJ_CACHE/.gitignore.$(timestamp)" \
			"git"
	}

	#@ Initialize Cargo project
	init_cargo || return $?

	#@ Initialize gitignore
	init_gitignore || return $?

	#@ Build project
	project_build || return $?
}

project_build() {
	[ "$CMD_CARGO" ] || {
		pout_status \
			--error "Build failed" \
			--dependency "cargo"
		return 127
	}
	cargo build --release
	cargo install --path "$PRJ_ROOT"
}

project_update() {
	[ "$CMD_NIX" ] && nix flake update
	[ "$CMD_CARGO" ] && cargo update
	if [ "$CMD_GEET" ]; then
		geet --push "$@"
	else
		project_git "$@"
	fi
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

project_format() {
	[ "$CMD_TREEFMT" ] &&
		treefmt \
			--tree-root="$PRJ_ROOT" \
			--config-file "$PRJ_CONF/treefmt.toml" \
			--allow-missing-formatter \
			--ci

	[ "$CMD_JUST" ] && just --fmt --quiet
}

project_clean() {
	case "${1:-}" in
	-x | --reset)
		cleanup_paths=".git .cargo Cargo.toml Cargo.lock src .direnv target flake.lock"
		return
		;;
	*)
		cleanup_paths=".direnv .cache"
		[ "$CMD_CARGO" ] && cargo clean
		;;
	esac

	#@ Save and set IFS
	old_ifs="$IFS"
	IFS=' '

	#@ Remove files safely with proper quoting
	for item in $cleanup_paths; do
		target="${PRJ_ROOT:?}/${item}"
		[ -e "$target" ] && {
			if [ "$CMD_TRASH" ]; then
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
