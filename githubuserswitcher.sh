#!/usr/bin/env bash
# githubuserswitcher.sh - Switch GitHub user configuration for a local git repository
set -euo pipefail

# ---------------------------------------------------------------------------
# Hardcoded user configuration
# ---------------------------------------------------------------------------
USER_NAMES=(marcogvorwerk marcoguastalli)
USER_EMAILS=(marcogvorwerk marcoguastalli)

# ---------------------------------------------------------------------------
# Internal flags
# ---------------------------------------------------------------------------
DRY_RUN=false

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
print_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [USERNAME]

Switch the local git user configuration (user.name / user.email) for the
current repository and re-authenticate with the GitHub CLI (gh).

Options:
  --dry-run    Show what would be done without making any changes.
  --help       Show this help message and exit.

Arguments:
  USERNAME     Directly select a user without the interactive prompt.
               Must be one of: ${USER_NAMES[*]}

Exit codes:
  0  Success / no action needed.
  1  User selection invalid or cancelled.
  2  Runtime error (missing dependency, not a git repo handled separately).
EOF
}

# Print a message to stdout
msg() { printf '%s\n' "$@"; }

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
check_dependencies() {
  local missing=()
  for cmd in git gh; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  if [[ ${#missing[@]} -gt 0 ]]; then
    msg "Error: the following required tools are not installed: ${missing[*]}"
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# Core functions
# ---------------------------------------------------------------------------

# Returns 0 if current directory is inside a git repository, 1 otherwise.
detect_git_repo() {
  git rev-parse --git-dir &>/dev/null
}

# Reads the local git user config. Sets GIT_USER_NAME and GIT_USER_EMAIL.
read_git_config() {
  GIT_USER_NAME=$(git config --local user.name 2>/dev/null || true)
  GIT_USER_EMAIL=$(git config --local user.email 2>/dev/null || true)
}

# Prints the list of configured users (one per line, with index).
list_users() {
  local i
  for i in "${!USER_NAMES[@]}"; do
    msg "  $((i + 1))) ${USER_NAMES[$i]}"
  done
  msg "  $((${#USER_NAMES[@]} + 1))) Cancel"
}

# Applies the user config at index $1 (0-based).
apply_user_config() {
  local idx=$1
  local name="${USER_NAMES[$idx]}"
  local email="${USER_EMAILS[$idx]}"

  if [[ "$DRY_RUN" == true ]]; then
    msg "[dry-run] Would run: git config --local user.name \"${name}\""
    msg "[dry-run] Would run: git config --local user.email \"${email}\""
    msg "[dry-run] Would run: gh auth login"
    return 0
  fi

  git config --local user.name  "$name"
  git config --local user.email "$email"
}

# Runs gh auth login and gh auth status. Swallows non-fatal errors.
run_gh_auth() {
  if [[ "$DRY_RUN" == true ]]; then
    msg "[dry-run] Would run: gh auth login"
    msg "[dry-run] Would run: gh auth status"
    return 0
  fi
  gh auth login || true
  gh auth status || true
}

# Prompts the user to select a user from the list.
# Sets SELECTED_IDX (0-based) or exits with code 1 if cancelled/invalid.
prompt_user_select() {
  msg ""
  msg "Select a user:"
  list_users
  msg ""
  local max_valid=$(( ${#USER_NAMES[@]} + 1 ))
  local choice
  read -r -p "Enter number [1-${max_valid}]: " choice

  # Validate numeric input
  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    msg "Invalid selection: '${choice}'. Exiting."
    exit 1
  fi

  if (( choice < 1 || choice > max_valid )); then
    msg "Invalid selection: '${choice}'. Exiting."
    exit 1
  fi

  # Cancel option
  if (( choice == max_valid )); then
    msg "Cancelled. Cheers"
    exit 1
  fi

  SELECTED_IDX=$(( choice - 1 ))
}

# Resolves a username string to a 0-based index in USER_NAMES.
# Sets SELECTED_IDX or exits with code 1 if not found.
resolve_username() {
  local target="$1"
  local i
  for i in "${!USER_NAMES[@]}"; do
    if [[ "${USER_NAMES[$i]}" == "$target" ]]; then
      SELECTED_IDX=$i
      return 0
    fi
  done
  msg "Error: unknown user '${target}'."
  msg "Known users: ${USER_NAMES[*]}"
  exit 1
}

# ---------------------------------------------------------------------------
# Main flow
# ---------------------------------------------------------------------------
main() {
  local direct_user=""

  # Parse arguments
  for arg in "$@"; do
    case "$arg" in
      --help)
        print_help
        exit 0
        ;;
      --dry-run)
        DRY_RUN=true
        ;;
      -*)
        msg "Unknown option: '${arg}'. Use --help for usage."
        exit 2
        ;;
      *)
        direct_user="$arg"
        ;;
    esac
  done

  check_dependencies

  # --- Not a git repository ---
  if ! detect_git_repo; then
    msg "This folder is not a git repository."
    exit 0
  fi

  read_git_config

  # --- Direct user switch (e.g. githubuserswitcher.sh marcogvorwerk) ---
  if [[ -n "$direct_user" ]]; then
    resolve_username "$direct_user"
    apply_user_config "$SELECTED_IDX"
    run_gh_auth
    msg ""
    msg "Git user switched to:"
    msg "  user.name  = ${USER_NAMES[$SELECTED_IDX]}"
    msg "  user.email = ${USER_EMAILS[$SELECTED_IDX]}"
    exit 0
  fi

  # --- No existing local config ---
  if [[ -z "$GIT_USER_NAME" && -z "$GIT_USER_EMAIL" ]]; then
    msg ""
    msg "No git user configuration found in this repository. Add one? (y/n)"
    local answer
    read -r answer
    case "$answer" in
      [Yy]*)
        prompt_user_select
        apply_user_config "$SELECTED_IDX"
        run_gh_auth
        msg ""
        msg "New git configuration:"
        msg "  user.name  = ${USER_NAMES[$SELECTED_IDX]}"
        msg "  user.email = ${USER_EMAILS[$SELECTED_IDX]}"
        exit 0
        ;;
      *)
        msg "Cheers"
        exit 0
        ;;
    esac
  fi

  # --- Existing local config ---
  msg ""
  msg "Current git configuration:"
  msg "  user.name  = ${GIT_USER_NAME}"
  msg "  user.email = ${GIT_USER_EMAIL}"
  run_gh_auth
  msg ""
  msg "Change it? (y/n)"
  local answer
  read -r answer
  case "$answer" in
    [Yy]*)
      prompt_user_select
      apply_user_config "$SELECTED_IDX"
      run_gh_auth
      msg ""
      msg "Git user switched to:"
      msg "  user.name  = ${USER_NAMES[$SELECTED_IDX]}"
      msg "  user.email = ${USER_EMAILS[$SELECTED_IDX]}"
      exit 0
      ;;
    *)
      msg "Cheers"
      exit 0
      ;;
  esac
}

# Only run main when the script is executed directly (not sourced for testing).
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
