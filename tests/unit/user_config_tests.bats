#!/usr/bin/env bats
# Unit tests for internal functions of githubuserswitcher.sh

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/githubuserswitcher.sh"

# ---------------------------------------------------------------------------
# Helpers – source only the functions, skip main()
# ---------------------------------------------------------------------------
load_functions() {
  # We source the script with a guard so main() is never executed.
  # The trick: define main() as a no-op before sourcing.
  # shellcheck disable=SC1090
  (
    main() { :; }
    # shellcheck source=/dev/null
    source "$SCRIPT"
  )
}

# ---------------------------------------------------------------------------
# detect_git_repo
# ---------------------------------------------------------------------------

@test "detect_git_repo: returns 0 inside a git repo" {
  local tmpdir
  tmpdir=$(mktemp -d)
  git -C "$tmpdir" init -q

  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    cd '${tmpdir}'
    detect_git_repo
  "
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
}

@test "detect_git_repo: returns non-zero outside a git repo" {
  local tmpdir
  tmpdir=$(mktemp -d)

  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    cd '${tmpdir}'
    detect_git_repo
  "
  rm -rf "$tmpdir"
  [ "$status" -ne 0 ]
}

# ---------------------------------------------------------------------------
# read_git_config
# ---------------------------------------------------------------------------

@test "read_git_config: reads existing local config" {
  local tmpdir
  tmpdir=$(mktemp -d)
  git -C "$tmpdir" init -q
  git -C "$tmpdir" config --local user.name  "testuser"
  git -C "$tmpdir" config --local user.email "testuser@example.com"

  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    cd '${tmpdir}'
    read_git_config
    echo \"\$GIT_USER_NAME\"
    echo \"\$GIT_USER_EMAIL\"
  "
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "testuser" ]
  [ "${lines[1]}" = "testuser@example.com" ]
}

@test "read_git_config: empty strings when no config is set" {
  local tmpdir
  tmpdir=$(mktemp -d)
  git -C "$tmpdir" init -q

  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    cd '${tmpdir}'
    read_git_config
    echo \"name=\${GIT_USER_NAME}\"
    echo \"email=\${GIT_USER_EMAIL}\"
  "
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "name=" ]
  [ "${lines[1]}" = "email=" ]
}

# ---------------------------------------------------------------------------
# list_users
# ---------------------------------------------------------------------------

@test "list_users: outputs all configured users plus Cancel" {
  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    list_users
  "
  [ "$status" -eq 0 ]
  # Should contain index 1 and 2 for configured users
  echo "${output}" | grep -q "1)"
  echo "${output}" | grep -q "2)"
  # Cancel option is always the last one
  echo "${output}" | grep -q "Cancel"
}

@test "list_users: contains marcogvorwerk" {
  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    list_users
  "
  [ "$status" -eq 0 ]
  echo "${output}" | grep -q "marcogvorwerk"
}

@test "list_users: contains marcoguastalli" {
  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    list_users
  "
  [ "$status" -eq 0 ]
  echo "${output}" | grep -q "marcoguastalli"
}

# ---------------------------------------------------------------------------
# apply_user_config
# ---------------------------------------------------------------------------

@test "apply_user_config: sets user.name and user.email for index 0" {
  local tmpdir
  tmpdir=$(mktemp -d)
  git -C "$tmpdir" init -q

  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    cd '${tmpdir}'
    apply_user_config 0
    git config --local user.name
    git config --local user.email
  "
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "marcogvorwerk" ]
  [ "${lines[1]}" = "marcogvorwerk" ]
}

@test "apply_user_config: sets user.name and user.email for index 1" {
  local tmpdir
  tmpdir=$(mktemp -d)
  git -C "$tmpdir" init -q

  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    cd '${tmpdir}'
    apply_user_config 1
    git config --local user.name
    git config --local user.email
  "
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "marcoguastalli" ]
  [ "${lines[1]}" = "marcoguastalli" ]
}

@test "apply_user_config: dry-run does not write git config" {
  local tmpdir
  tmpdir=$(mktemp -d)
  git -C "$tmpdir" init -q

  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    DRY_RUN=true
    cd '${tmpdir}'
    apply_user_config 0
    git config --local user.name 2>/dev/null || echo 'no-name'
  "
  rm -rf "$tmpdir"
  [ "$status" -eq 0 ]
  echo "${output}" | grep -q "dry-run"
  echo "${output}" | grep -q "no-name"
}

# ---------------------------------------------------------------------------
# resolve_username
# ---------------------------------------------------------------------------

@test "resolve_username: resolves marcogvorwerk to index 0" {
  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    resolve_username 'marcogvorwerk'
    echo \"\$SELECTED_IDX\"
  "
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "0" ]
}

@test "resolve_username: resolves marcoguastalli to index 1" {
  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    resolve_username 'marcoguastalli'
    echo \"\$SELECTED_IDX\"
  "
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1" ]
}

@test "resolve_username: exits 1 for unknown user" {
  run bash -c "
    main() { :; }
    source '${SCRIPT}'
    resolve_username 'nobody'
  "
  [ "$status" -eq 1 ]
}
