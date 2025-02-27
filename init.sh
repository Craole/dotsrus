#!/bin/sh

# set -eu
main() {
  #@ Initialize the script
  initialize_defaults
  # initialize_core_utils

  # initialize_dependencies
  # initialize_output_mode

  # pout_dependencies
  # initialize_output_mode
  # initialize_core_utils
  # initialize_bin_utils

  #@ Initialize the project
  # project_info
  # project_init

  #@ Load the shell
  # starship_wrapper
  # zoxide_wrapper
  # thefuck_wrapper
  # fastfetch_wrapper
}

initialize_defaults() {
  verbosity="info"  #? 0: quiet, 1: error, 2: warn, 3: info, 4: debug, 5: trace
  color_mode="auto" #? 0: none, 1|auto: ansi/tput
  icon_mode="auto"  #? 0: none, 1: ascii, 2: unicode, 3: emoji

  PRJ_ROOT="$(get_root_path)"
  [ -n "${PRJ_ROOT}" ] || {
    printf "Unable to determine project root. Ensure you are in a project directory\n"
    exit 1
  }

  PRJ_BIN="${PRJ_ROOT}/scripts"
  PRJ_CONF="${PRJ_ROOT}/.config"
  PRJ_DOCS="${PRJ_ROOT}/documentation"
  PRJ_CACHE="${PRJ_ROOT}/.cache"
  PRJ_README="${PRJ_ROOT}/README"
  PRJ_LICENSE="${PRJ_ROOT}/LICENSE"
  PRJ_NAME="$(
    printf '%s' "${PRJ_ROOT##*/}" |
      tr '[:upper:]' '[:lower:]' |
      sed '
          s/[^[:alnum:]]/_/g
          s/_\{2,\}/_/g
          s/^_//
          s/_$//
        '
  )"
  PATH="$(initiliaze_bin "${PRJ_BIN}")"

  printf "PRJ_ROOT: %s\n" "${PRJ_ROOT}"
  printf "PRJ_BIN: %s\n" "${PRJ_BIN}"
  printf "PRJ_CONF: %s\n" "${PRJ_CONF}"
  printf "PRJ_DOCS: %s\n" "${PRJ_DOCS}"
  printf "PRJ_CACHE: %s\n" "${PRJ_CACHE}"
  printf "PRJ_README: %s\n" "${PRJ_README}"
  printf "PRJ_LICENSE: %s\n" "${PRJ_LICENSE}"
  printf "PRJ_NAME: %s\n" "${PRJ_NAME}"

  printf "%s\n" "${PATH}" | tr ':' '\n' | tail -n 4
  export PRJ_ROOT PRJ_BIN PRJ_CONF PRJ_NAME PRJ_DOCS PRJ_CACHE PRJ_README PRJ_LICENSE
}

initialize_dependencies() {
  define_dependencies() {
    #| Core Build Tools
    core_tools="
      cargo           #? Rust package manager
      git             #? Version control
      nix             #? Package manager
      rustc           #? Rust compiler
    "

    #| Development Tools
    dev_tools="
      code            #? VSCode editor
      direnv          #? Directory environments
      hx              #? Helix editor
      just            #? Command runner
      taplo           #? TOML tools
      treefmt         #? Formatters
    "

    #| CLI Enhancements
    cli_tools="
      bat             #? Better cat
      dust            #? Better du
      eza             #? Better ls
      fd              #? Better find
      lsd             #? Better ls
      pls             #? Better sudo
      rg              #? Better grep
      geet            #? Git wrapper
      thefuck         #? Command correction
      zoxide          #? Better cd
    "

    #| Project Specific
    project_tools="
      dotsrus         #? Environment manager
      fastfetch       #? System info
      mktemp          #? Temp files
      realpath        #? Path resolution
      starship        #? Shell prompt
      tokei           #? Code statistics
    "

    printf '%s' "$core_tools $dev_tools $cli_tools $project_tools"
  }

  parse_dependencies() {
    [ $# -eq 0 ] && return 1
    deps="$(define_dependencies)"

    case "$1" in
    --tmp)
      # Get max length for right alignment
      max_len=$(printf '%s\n' "$deps" |
        sed -n 's/[[:space:]]*\([^#[:space:]]*\)[[:space:]]*#?.*/\1/p' |
        while IFS= read -r line; do
          printf '%s\n' "${#line}"
        done |
        sort -nr |
        head -n1)

      # Format with right-aligned commands
      printf '%s\n' "$deps" | while IFS= read -r line; do
        case "$line" in
        *"#|"*)
          [ -n "${printed:-}" ] && printf '\n'
          printf '=== %s ===\n' "${line##*#|}"
          printed=1
          ;;
        *"#?"*)
          name=${line%%#?*}
          name=${name## }
          desc=${line##*#?}
          desc=${desc## }
          printf "%${max_len}s  │  %s\n" "$name" "$desc"
          ;;
        esac
      done | sed '${/^$/d}'
      ;;
    --info)
      printf '%s\n' "$deps" |
        awk '
          /^[[:space:]]*#\|/ {
              if (NR > 1) printf "\n"
              sub(/^[[:space:]]*#\|[[:space:]]*/, "")
              printf "=== %s ===\n", $0
              next
          }
          /^[[:space:]]*[^[:space:]#]+[[:space:]]*#\?/ {
              name = $0
              sub(/[[:space:]]*#\?.*$/, "", name)
              desc = $0
              sub(/^.*#\?[[:space:]]*/, "", desc)
              printf "%20s  │  %s\n", name, desc
          }
        ' | sed '${/^$/d}'
      ;;
    --cmd)
      printf '%s\n' "$deps" |
        sed -n 's/[[:space:]]*\([^#[:space:]]*\)[[:space:]]*#?.*/\1/p' |
        grep -v '^$' |
        tr '\n' ' ' |
        sed 's/ $//'
      ;;
    *) return 1 ;;
    esac
  }

  cache_dependencies() {
    for dependency in $(parse_dependencies --cmd); do
      #@ Define	the variable name in uppercase
      var="$(printf "CMD_%s" "$dependency" | tr '[:lower:]' '[:upper:]')"

      #@ Get the absolute path of the dependency
      val="$(command -v "$dependency" || echo "")"

      #@ Export the variable
      eval "export $var=\"$val\""
    done

  }

  cache_dependencies

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
    case "${verbosity:-}" in
    '' | 0 | off | false | quiet) VERBOSITY_LEVEL=${VERBOSITY_LEVEL_QUIET+x} ;;
    1 | on | true | error) VERBOSITY_LEVEL=${VERBOSITY_LEVEL_ERROR+x} ;;
    2 | warn) VERBOSITY_LEVEL=${VERBOSITY_LEVEL_WARN+x} ;;
    3 | info) VERBOSITY_LEVEL=${VERBOSITY_LEVEL_INFO+x} ;;
    4 | debug) VERBOSITY_LEVEL=${VERBOSITY_LEVEL_DEBUG+x} ;;
    5 | trace) VERBOSITY_LEVEL=${VERBOSITY_LEVEL_TRACE+x} ;;
    *)
      if [ "${verbosity}" -gt "${VERBOSITY_LEVEL_TRACE+x}" ] >/dev/null 2>&1; then
        VERBOSITY_LEVEL="${VERBOSITY_LEVEL_TRACE+x}"
      elif [ "${verbosity+x}" -lt "${VERBOSITY_LEVEL_QUIET+x}" ] >/dev/null 2>&1; then
        VERBOSITY_LEVEL="${VERBOSITY_LEVEL_QUIET+x}"
      else
        VERBOSITY_LEVEL="${VERBOSITY_LEVEL_INFO+x}"
      fi
      ;;
    esac

    #@ Set verbosity levels globally
    export VERBOSITY_LEVEL VERBOSITY_LEVEL_QUIET VERBOSITY_LEVEL_ERROR VERBOSITY_LEVEL_WARN VERBOSITY_LEVEL_INFO VERBOSITY_LEVEL_DEBUG VERBOSITY_LEVEL_TRACE
  }

  set_attributes() {
    #@ Define format attributes
    if [ -n "${CMD_TPUT}" ]; then
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
    [ -n "${NO_COLOR+x}" ] && return                # Honor NO_COLOR
    [ "${TERM_COLOR_SUPPORTED+x}" -ne 1 ] && return # Need color support

    case "${color_mode:-auto}" in
    '' | null | false | no | 0 | none) return ;; # Explicitly disabled
    *) ;;                                        # Continue with colors
    esac

    #@ Set the basic 8 colors
    base_colors="BLACK RED GREEN YELLOW BLUE MAGENTA CYAN WHITE"
    i=0
    for color in ${base_colors+x}; do
      if [ -n "${CMD_TPUT+x}" ]; then
        eval "CLR_FG_${color}=\"\$(tput setaf ${i})\""
        eval "CLR_BG_${color}=\"\$(tput setab ${i})\""
        eval "export CLR_FG_${color} CLR_BG_${color}"
      else
        eval "CLR_FG_${color}=\$'\\033[3${i}m'"
        eval "CLR_BG_${color}=\$'\\033[4${i}m'"
        eval "export CLR_FG_${color} CLR_BG_${color}"
      fi
      i=$((i + 1))
    done

    #@ Extended colors for 256-color terminals
    if [ "${TERM_COLORS+x}" -ge 256 ]; then
      #| Reds
      CLR_FG_DARKRED="${CLR_FG_RED+x}" CLR_FG_MAROON="${CLR_FG_RED+x}"
      export CLR_FG_DARKRED CLR_FG_MAROON

      #| Yellows
      CLR_FG_GOLD="${CLR_FG_YELLOW+x}" CLR_FG_ORANGE="${CLR_FG_YELLOW+x}"
      export CLR_FG_GOLD CLR_FG_ORANGE

      #| Greens
      CLR_FG_LIME="${CLR_FG_GREEN+x}" CLR_FG_OLIVE="${CLR_FG_GREEN+x}"
      export CLR_FG_LIME CLR_FG_OLIVE

      #| Blues
      CLR_FG_TEAL="${CLR_FG_CYAN+x}" CLR_FG_NAVY="${CLR_FG_BLUE+x}"
      export CLR_FG_TEAL CLR_FG_NAVY

      #| Purples
      CLR_FG_PURPLE="${CLR_FG_MAGENTA+x}" CLR_FG_PINK="${CLR_FG_MAGENTA+x}"
      export CLR_FG_PURPLE CLR_FG_PINK
    fi
  }

  set_icons() {
    #@ Check if icons are disabled globally
    [ -n "${NO_ICONS+x}" ] && return #? Honor NO_ICONS

    #@ Set the icon mode based on preferences and capabilities
    ICON_MODE="${icon_mode:-"${ICON_MODE+x}:-auto}"}"

    #@ Check and update icon mode
    case "${ICON_MODE}" in
    0 | none | null | false | no)
      return
      ;; #? Explicitly disabled
    1 | 2 | 3)
      [ "${ICON_MODE}" -gt "${TERM_LEVEL}" ] &&
        ICON_MODE=${TERM_LEVEL} #? Clamped to terminal level
      ;;
    auto | *)
      ICON_MODE=${TERM_LEVEL}
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
    0 | *) #| No icons
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

  pout_dependencies() {
    pout_header "Dependencies"
    parse_dependencies --info
  }

  #@ Initialize functions
  detect_terminal_capabilities
  set_verbosity_level
  set_attributes
  set_colors
  set_icons
}

get_root_path() {
  #@ Initialize variables
  root_dir=""

  #@ Find Git repository root first
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    root_dir="$(git rev-parse --show-toplevel)"
  else
    #@ Check for flake.nix or Cargo.toml
    while [ "${dir}" != "/" ]; do
      if [ -f "${dir}/flake.nix" ] || [ -f "${dir}/Cargo.toml" ]; then
        root_dir="${dir}"
        break
      fi
    done
  fi

  #@ Return the root directory only if it's absolute
  [ "${root_dir}" = "." ] || printf "%s" "${root_dir}"
}

initiliaze_bin() {
  #@ Initialize variables
  [ $# -eq 0 ] && return 1
  NEW_PATH="${PATH:-}"

  #@ Allow multiple directories
  for bin in "$@"; do

    #@ Ensure the directory exists
    [ -z "$bin" ] && continue
    mkdir -p "${bin}"

    #@ Handle first entry without colon
    if [ -z "$NEW_PATH" ]; then
      NEW_PATH="$bin"
      continue
    fi

    #@ Append the directory to the PATH if it doesn't already exist
    case ":${NEW_PATH}:" in
    *":${bin}:"*) ;;
    *) NEW_PATH="${NEW_PATH}:${bin}" ;;
    esac

  done

  #@ Return the new path
  printf "%s" "${NEW_PATH}"
}

initialize_core_utils() {
  pout_status() {
    #@ Initialize variables
    status_of="" val="" ctx="${PRJ_NAME}" context=""

    #@ Parse arguments
    while [ "$#" -gt 0 ]; do
      case "$1" in
      --success) icon="${ICON_SUCCESS}" ;;
      --failure) icon="${ICON_FAILURE}" ;;
      --error)
        icon="${ICON_FAILURE}"
        status_of="error"
        val="$2"
        shift
        ;;
      --dependency)
        icon="${ICON_ERROR}"
        status_of="dep"
        val="$2"
        shift
        ;;
      --context)
        context="$2"
        shift
        ;;
      *)
        val="${val:+${val} }$1"
        ;;
      esac
      shift
    done

    #@ Print based on status type
    case "${status_of}" in
    dep)
      printf "%s%s %s required by the %s%s\n" \
        "${icon}" \
        "${CLR_FG_RED}${FMT_HIGHLIGHT}Missing Dependency${FMT_RESET}" \
        "${FMT_EMPHASIS}${val}${FMT_RESET}" \
        "${FMT_BOLD}${context:-${ctx}}${FMT_RESET}" \
        "$(
          # shellcheck disable=SC2312
          if [ -n "${context}" ]; then
            printf " function."
          else
            printf " project."
          fi
        )" >&2
      ;;
    error)
      printf "%sERROR: %s\n" "${icon}" "${val}" >&2
      ;;
    *)
      printf "%s%s\n" "${icon}" "${val}"
      ;;
    esac
  }

  pout_header() {
    #DOC Print a heading with a title.
    #DOC
    #DOC The heading is printed with a highlighted color and the title is centered.
    #DOC The heading is enclosed in '|>' and '<|' delimiters.
    printf "\n%s|> %s <|%s\n" "${FMT_HIGHLIGHT}" "$*" "${FMT_RESET}"
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
        "$((name_width + name_adj))" "${fmt_name}" \
        "$((sep_width + sep_adj))" "${fmt_sep}" \
        "${val_margin}" "" \
        "${fmt_val}"
    }

    #@ Process flags
    case "${1-}" in
    --app)
      case "${ICON_MODE}" in
      0) margin=2 sep_width=4 ;;
      *) margin=0 sep_width=2 ;;
      esac
      shift
      name="$1"
      eval "val=\"\$CMD_$(printf "%s" "${name}" |
        tr '[:lower:]' '[:upper:]' || :)\""
      if [ -n "${val-}" ]; then
        icon="${ICON_SUCCESS}"
      else
        icon="${ICON_FAILURE}"
        val="Not found"
      fi
      format_and_print "${name}" "${val}"
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
      pattern='^alias [A-Z]='
      shift
      ;;
    *) ;;
    esac

    #@ Handle aliases if requested
    if [ -n "${pattern-}" ]; then
      names=$(alias | grep "${pattern}" | cut -d'=' -f1 | cut -d' ' -f2)
      for name in ${names}; do
        val="$(alias "${name}" | cut -d'=' -f2- | sed "s/^'//;s/'$//")"
        [ -n "${val}" ] && format_and_print "${name}" "${val}"
      done
    else
      #@ Handle variables
      for var; do
        eval "val=\"\${${var}-}\""
        [ -n "${val}" ] && format_and_print "${var}" "${val}"
      done
    fi
  }

  git_has_changes() {
    [ -n "$(git status --porcelain 2>/dev/null || :)" ]
  }

  git_has_remote() {
    git remote get-url origin >/dev/null 2>&1
  }

  pathof_flake_or_git() {
    #? Check if the current directory or any parent directory has a flake.nix file
    dir="${PWD}"
    while [ "${dir}" != "/" ]; do
      if [ -f "${dir}/flake.nix" ]; then
        printf "%s" "${dir}"
        return 0
      fi
      dir=$(dirname "${dir}")
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
      case "$1" in */*) mkdir -p "$(dirname "$1")" ;; *) ;; esac

      #@ Create the file
      touch "$1"

      #@ Shift to the next argument
      shift
    done
  }

  find_first() {
    search_root="${PRJ_ROOT}"
    search_depth=2
    search_type="file"

    while [ "$#" -ge 1 ]; do
      case "$1" in
      --path | --root) [ -n "${2}" ] && search_root=${2} ;;
      --target) [ -n "${2}" ] && search_target="${2}" ;;
      --depth) [ -n "${2}" ] && search_depth="${2}" ;;
      --type) search_type="${2}" ;;
      *) search_target="${1}" ;;
      esac
      shift
    done

    search_type="${search_type%"${search_type#?}"}"

    find \
      -L "${search_root}" \
      -maxdepth "${search_depth}" \
      -type "${search_type}" \
      -iname "${search_target}" |
      head -n1
  }

  is_newer() {
    #@ Initialize variables
    file1="$1" file2="$2"

    #@ Verify files exist
    [ -f "${file1}" ] || return 1
    [ -f "${file2}" ] || return 2

    #@ Find the newer file using find
    newer_file="$(find "${file1}" -prune -newer "${file2}")"

    #@ Debug
    # printf "File 1: %s\nFile 2: %s\nNewer File: %s" \
    #   "${file1}" "${file2}" "${newer_file:-}"

    #@ Check if a newer file was found
    [ -n "${newer_file}" ]
  }

  is_different() {
    #@ Initialize variables
    file1="$1" file2="$2"

    #@ Verify files exist
    [ -f "${file1}" ] || return 2
    [ -f "${file2}" ] || return 2

    #@ Compare file contents
    ! cmp -s "${file1}" "${file2}"
  }

  timestamp() {
    date '+%Y%m%d_%H%M%S'
  }

  generate_temp() {
    #@ Create a temporary file with a unique name
    if [ -n "${CMD_MKTEMP}" ] || command -v mktemp >/dev/null 2>&1; then
      __tmp="$(mktemp)" || return 1
    else
      __tmp="${TMPDIR:-/tmp}/${0##*/}.$$.tmp"
      touch "${__tmp}" || return 1
    fi

    #@ Cleanup if the script exits
    trap 'rm -f "$tmp"' EXIT

    #@ Return the path to the temporary file
    printf '%s' "${__tmp}"
  }

  get_absolute_path() {
    path="$1"

    if
      [ -n "${CMD_REALPATH}" ] ||
        command -v realpath >/dev/null 2>&1
    then
      realpath "${path}"
    elif
      [ -n "${CMD_READLINK}" ] ||
        command -v readlink >/dev/null 2>&1
    then
      readlink -f "${path}"
    else
      #@ Fallback to concatenating with pwd if realpath or readlink -f is not available
      pwd="$(pwd)"
      case "${path}" in
      /*) printf "%s\n" "${path}" ;;
      *) printf "%s\n" "${pwd}/${path}" ;;
      esac
    fi
  }

  get_relative_path() {
    path1="$1" path2="$2"
    dir1="" dir2="" common=""

    #@ Get absolute paths
    dir1=$(dirname "$(readlink -f "${path1}" || :)")
    dir2=$(dirname "$(readlink -f "${path2}" || :)")

    #@ Find common parent
    common=$(printf '%s\n%s\n' "${dir1}" "${dir2}" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/')

    if [ -n "${common}" ] && [ "${common}" != "/" ]; then
      #@ Show relative paths
      path1="${path1#"${common}"}"
      path2="${path2#"${common}"}"
      printf '%s\n%s' "${path1#/}" "${path2#/}"
    else
      #@ Show full paths
      printf '%s\n%s' "${path1}" "${path2}"
    fi
  }

  check_dependencies() {
    #@ Initialize variables
    context=""
    deps=""

    #@ Parse options and collect deps
    while [ "$#" -gt 0 ]; do
      case "$1" in
      --context)
        context="$2" # Override auto-context
        shift
        ;;
      *)
        deps="${deps:+${deps} }$1"
        ;;
      esac
      shift
    done

    #@ Check each dependency
    for dep in ${deps}; do
      dep_upper=$(printf '%s' "${dep}" | tr '[:lower:]' '[:upper:]')
      dep_lower=$(printf '%s' "${dep}" | tr '[:upper:]' '[:lower:]')

      eval "[ -n \"\${CMD_${dep_upper}+x}\" ]" || {
        pout_status \
          --error "Initialization failed" \
          --dependency "${dep_lower}" \
          --context "${context}"
        return 127
      }
    done
  }

  sync_file() {
    #@ Initialize variables
    bac="" src="" des="" deps="" ctx="sync_file"

    #@ Parse options
    while [ $# -gt 0 ]; do
      case "$1" in
      --src)
        src=$2
        shift 2
        ;;
      --des)
        des=$2
        shift 2
        ;;
      --bac)
        bac=$2
        shift 2
        ;;
      --dep)
        deps="${deps:+$deps }$2"
        shift 2
        ;;
      --ctx)
        ctx="$2"
        shift 2
        ;;
      *)
        printf '%s\n' "Error: Invalid option $1" >&2
        return 1
        ;;
      esac
    done

    #@ Validate required params
    [ -z "${src}" ] && {
      pout_status --error "Source file path not provided"
      return 1
    }
    [ -z "${des}" ] && {
      pout_status --error "Destination file path not provided"
      return 1
    }
    [ -z "${bac}" ] && bac="${PRJ_CACHE}/$(basename "${src}").$(timestamp)"

    #@ Check dependency
    check_dependencies --context "${ctx}" "${deps}"

    #@ Verify source exists
    [ ! -f "${src}" ] && {
      pout_status --context "$ctx" --error "Source file missing: $src"
      return 1
    }

    #@ Handle file operations
    if [ -e "${des}" ]; then
      if [ -L "${des}" ]; then
        #@ Is symlink - backup and remove
        cp "${des}" "${bac}"
        unlink "${des}"
        cp "${src}" "${des}"
      elif [ -f "${des}" ]; then

        #@ Skip if the source and target files are same
        is_different "${src}" "${des}"

        #@ Ensure the backup directory exists
        mkdir -p "$(dirname "${bac}")"

        #@ Check which file is newer and sync accordingly
        if is_newer "${src}" "${des}"; then

          #@ Backup the existing destination file
          cp "${des}" "${bac}" || {
            pout_status --error "Failed to backup: ${des}"
            return "$?"
          }

          #@ Replace the destination file with a copy of the source
          if cp "${src}" "${des}" >/dev/null 2>&1; then
            pout_status --success "Synced" "${des}" "with" "${src}"
          else
            pout_status --failure "Failed to sync ${des} with ${src}"
            return "$?"
          fi
        else

          #@ Backup source
          cp "${src}" "${bac}" || {
            pout_status --error "Failed to backup: ${src}"
            return "$?"
          }

          #@ Replace the source file with a copy of the destination
          if cp "${des}" "${src}" >/dev/null 2>&1; then

            paths=$(get_relative_path "${src}" "${des}")
            src_rel=$(echo "${paths}" | sed -n '1p')
            des_rel=$(echo "${paths}" | sed -n '2p')
            pout_status --success "Synced" "${src_rel}" "with" "${des_rel}"
            # pout_status --success "Synced" "$src" "with" "$des"
          else
            pout_status --failure "Failed to sync ${src} with ${des}"
            return "$?"
          fi
        fi
      fi
    else
      #@ Create the target directory and copy
      mkdir -p "$(dirname "${des}")"

      #@ Create the destination file with a copy of the source
      if cp "${src}" "${des}" >/dev/null 2>&1; then
        pout_status --success "Created" "${des}" "from" "${src}"
      else
        pout_status --failure "Create" "${des}" from "${src}"
        return "$?"
      fi
    fi

    return 0
  }

  size_check() {
    pout_header "Storage Utilization"
    if [ -n "${CMD_DUST}" ]; then
      dust --reverse
    else
      du
    fi
  }

  pretty_os_print() {
    [ -n "${CMD_FIGLET}" ] ||
      command -v figlet >/dev/null 2>&1 ||
      return

    [ -n "${CMD_JQ}" ] ||
      command -v figlet >/dev/null 2>&1 ||
      return

    [ -n "${CMD_FASTFETCH}" ] ||
      command -v fastfetch >/dev/null 2>&1 ||
      return

    os_name="$(
      fastfetch -s os --format json |
        jq -r '.[0].result.name' |
        tr -d '\n'
    )"
    os_name_pretty="$(
      figlet -f slant "${os_name}" |
        awk 'NR > 1 { print prev } { prev = $0 }'
    )"
  }
}

initialize_wrappers() {

  fastfetch_wrapper() {
    [ -n "${CMD_FASTFETCH}" ] || return
    FASTFETCH_CONFIG="${FASTFETCH_CONFIG:-$1}"

    pretty_os_print() {
      [ -n "${CMD_FIGLET}" ] ||
        command -v figlet >/dev/null 2>&1 ||
        return

      [ -n "${CMD_JQ}" ] ||
        command -v figlet >/dev/null 2>&1 ||
        return

      [ -n "${CMD_FASTFETCH}" ] ||
        command -v fastfetch >/dev/null 2>&1 ||
        return

      os_name="$(
        fastfetch -s os --format json |
          jq -r '.[0].result.name' |
          tr -d '\n'
      )"
      os_name_pretty="$(
        figlet -f slant "${os_name}" |
          awk 'NR > 1 { print prev } { prev = $0 }'
      )"

      [ -n "${fetch_os}" ] &&
        printf "%s\n" "${os_name_pretty}"
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

  starship_wrapper() {
    check_dependencies starship || return $?
    eval "$(starship init bash)"
  }
}

projects_components() {
  project_info() {
    define_dependencies() {
      pout_header "Dependencies"

      for dependency in $DEPENDENCIES; do
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

      #@ Initialize dependency wrappers
      initialize_wrappers
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
      PRJ_CONF="$(dirname "$(find_first --root "$PRJ_ROOT" --target "init*")")"
      PRJ_INFO="$(find_first --root "$PRJ_ROOT" --target "readme*")"
      PRJ_CACHE="$PRJ_ROOT/.cache"
      PRJ_DOCS="$PRJ_ROOT/documentation"
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
      [ -n "${CMD_BAT}" ] && alias cat='bat --style=plain'
      [ -n "$CMD_CARGO" ] && alias A='cargo add'
      alias B='project_build'
      [ -n "$CMD_CARGO" ] && alias C='project_clean'
      [ -n "$CMD_CARGO" ] && alias D='cargo remove'

      alias E='editor_wrapper'

      alias F='project_format'

      [ -n "$CMD_CARGO" ] && alias G='cargo generate'

      [ -n "$CMD_HX" ] && alias H='helix_wrapper' #? Change to help

      alias I='project_init'

      [ -n "$CMD_JUST" ] && alias J='just'
      alias K='exit'
      if [ -n "$CMD_EZA" ]; then
        alias L='eza --long --almost-all --group-directories-first --color=always --icons=always --git --git-ignore --time-style relative --total-size --smart-group'
        alias Lt='L --tree'
      elif [ -n "$CMD_LSD" ]; then
        alias L='lsd --long --almost-all --group-directories-first --color=always --git --date=relative --versionsort --total-size'
        alias Lt='L --tree'
      else
        alias L='ls -lAhF --color=always --group-directories-first'
        alias Lt='L --recursive'
      fi
      [ -n "$CMD_PLS" ] && alias Lp='pls --det perm --det oct --det user --det group --det mtime --det git --det size --header false'
      alias M='mkdir --parents'
      [ -n "$CMD_CARGO" ] && alias N='cargo new'
      alias O='size_check'
      alias P='project_info'
      [ -n "$CMD_CARGO" ] && alias Q='cargo watch --quiet --clear --exec "run --quiet --"'
      [ -n "$CMD_CARGO" ] && alias R='cargo run --release'
      [ -n "$CMD_CARGO" ] && alias S='cargo search'
      alias T='create_file'
      alias U='project_update'
      alias V='editor_wrapper --visual'
      [ -n "$CMD_CARGO" ] && alias W='cargo watch --quiet --clear --exec "run --"'
      alias X='project_clean --reset'

      if [ -f "$PRJ_README" ]; then
        if [ -n "${READER+x}" ]; then
          reader="$READER"
        elif [ -n "$CMD_BAT" ]; then
          reader='bat'
        else
          reader='cat'
        fi
        alias Y='eval -- \"$reader\" \"$PRJ_README\"'
      else
        alias Y='project_info'
      fi
      alias Z='tokei'

      pout_header "Aliases"
      pout_env --alias-az
    }

    define_dependencies
    define_variables
    define_aliases
  }

  project_init() {
    pout_header "Project"

    update_cargo_pkgname() {
      #@ Verify required dependencies
      check_dependencies cargo || return $?

      #@ Initialize variables
      tmp="" file=""

      #@ Set up temporary file
      tmp="$(generate_temp)" || return "$?"

      #@ Update Cargo.toml if it exists
      if [ -f Cargo.toml ]; then
        file="$PRJ_ROOT/Cargo.toml"
        sed "s|^name = .*|name = \"$PRJ_NAME\"|" "$file" >"${tmp}"
        mv -- "$tmp" "$file"
      else
        cargo init --name "$PRJ_NAME"
      fi

    }

    sync_files() {
      sync_file \
        --src "$PRJ_CONF/cargo.toml" \
        --des "$PRJ_ROOT/.cargo/config.toml" \
        --dep cargo \
        --ctx project_init
      sync_file \
        --src "$PRJ_CONF/.gitignore" \
        --des "$PRJ_ROOT/.gitignore" \
        --dep git

      sync_file \
        --src "$PRJ_DOCS/LICENSE" \
        --des "$PRJ_ROOT/LICENSE"

      sync_file \
        --src "$PRJ_DOCS/README" \
        --des "$PRJ_ROOT/README"

    }

    #@ Initialize Cargo project
    update_cargo_pkgname
    sync_files

    #@ Build project
    project_build
  }

  project_build() {
    check_dependencies cargo || return $?
    cargo build --release
    cargo install --path "$PRJ_ROOT"
  }

  project_update() {
    [ "$CMD_NIX" ] && nix flake update
    [ "$CMD_CARGO" ] && cargo update

    if [ "${CMD_GEET+x}" ]; then
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
    fn_name="project_format"
    if check_dependencies --context "$fn_name" treefmt >/dev/null 2>&1; then
      treefmt_wrapper
    else
      check_dependencies --context "$fn_name" just &&
        just --fmt --quiet
    fi
  }

  project_clean() {
    case "${1:-}" in
    -x | --reset)
      cleanup_paths=".git .cargo Cargo.toml Cargo.lock src .direnv target flake.lock"
      return
      ;;
    *)
      cleanup_paths=".direnv .cache"
      chech_dependencies cargo --context project_clean && cargo clean
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
}

main "$@"
