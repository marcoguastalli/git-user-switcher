#!/usr/bin/env bats
# Integration tests – run the script end-to-end against real git repos.
# gh calls are stubbed so no network activity is required.

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/githubuserswitcher.sh"

# ---------------------------------------------------------------------------
# Setup / teardown – stub gh and keep a fresh tmpdir per test
# ---------------------------------------------------------------------------

setup() {
  TEST_DIR=$(mktemp -d)
  # Create a fake `gh` that always succeeds so we don't hit the network.
  GH_STUB_DIR=$(mktemp -d)
  cat >"${GH_STUB_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
# Stub: accept any gh subcommand silently
echo "[gh-stub] $*"
exit 0
STUB
  chmod +x "${GH_STUB_DIR}/gh"
  # Prepend stub dir so it shadows the real gh
  export PATH="${GH_STUB_DIR}:${PATH}"
}

teardown() {
  rm -rf "$TEST_DIR" "$GH_STUB_DIR"
}

# ---------------------------------------------------------------------------
# Helper: run script with simulated stdin
# ---------------------------------------------------------------------------
run_script() {
  # $1 = stdin string, remaining = script args
  local stdin_data="$1"; shift
  run bash -c "echo '${stdin_data}' | '${SCRIPT}' $*"
}

# ---------------------------------------------------------------------------
# Non-git directory
# ---------------------------------------------------------------------------

@test "integration: non-git directory exits 0 with correct message" {
  cd "$TEST_DIR"
  run bash -c "cd '${TEST_DIR}' && '${SCRIPT}'"
  [ "$status" -eq 0 ]
  echo "${output}" | grep -q "not a git repository"
}

# ---------------------------------------------------------------------------
# Git repo with no config – answer 'n' (skip)
# ---------------------------------------------------------------------------

@test "integration: repo with no config, answer no → exits 0 with Cheers" {
  git -C "$TEST_DIR" init -q
  run bash -c "echo 'n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 0 ]
  echo "${output}" | grep -q "Cheers"
}

# ---------------------------------------------------------------------------
# Git repo with no config – answer 'y', select user 1 (marcogvorwerk)
# ---------------------------------------------------------------------------

@test "integration: repo with no config, add marcogvorwerk → git config is set" {
  git -C "$TEST_DIR" init -q
  # Answer: y → 1
  run bash -c "printf 'y\n1\n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 0 ]
  local name
  name=$(git -C "$TEST_DIR" config --local user.name)
  local email
  email=$(git -C "$TEST_DIR" config --local user.email)
  [ "$name"  = "marcogvorwerk" ]
  [ "$email" = "marcogvorwerk" ]
}

# ---------------------------------------------------------------------------
# Git repo with no config – answer 'y', select user 2 (marcoguastalli)
# ---------------------------------------------------------------------------

@test "integration: repo with no config, add marcoguastalli → git config is set" {
  git -C "$TEST_DIR" init -q
  run bash -c "printf 'y\n2\n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 0 ]
  local name
  name=$(git -C "$TEST_DIR" config --local user.name)
  local email
  email=$(git -C "$TEST_DIR" config --local user.email)
  [ "$name"  = "marcoguastalli" ]
  [ "$email" = "marcoguastalli" ]
}

# ---------------------------------------------------------------------------
# Git repo with no config – answer 'y', select Cancel (option 3)
# ---------------------------------------------------------------------------

@test "integration: repo with no config, cancel selection → exits 1" {
  git -C "$TEST_DIR" init -q
  run bash -c "printf 'y\n3\n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 1 ]
  echo "${output}" | grep -q -i "cancel"
}

# ---------------------------------------------------------------------------
# Git repo with existing config – answer 'n'
# ---------------------------------------------------------------------------

@test "integration: repo with config, answer no → exits 0 with Cheers" {
  git -C "$TEST_DIR" init -q
  git -C "$TEST_DIR" config --local user.name  "marcogvorwerk"
  git -C "$TEST_DIR" config --local user.email "marcogvorwerk"
  run bash -c "echo 'n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 0 ]
  echo "${output}" | grep -q "Cheers"
}

# ---------------------------------------------------------------------------
# Git repo with existing config – answer 'y', switch to marcoguastalli
# ---------------------------------------------------------------------------

@test "integration: repo with config, switch to marcoguastalli" {
  git -C "$TEST_DIR" init -q
  git -C "$TEST_DIR" config --local user.name  "marcogvorwerk"
  git -C "$TEST_DIR" config --local user.email "marcogvorwerk"
  run bash -c "printf 'y\n2\n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 0 ]
  local name
  name=$(git -C "$TEST_DIR" config --local user.name)
  [ "$name" = "marcoguastalli" ]
}

# ---------------------------------------------------------------------------
# Direct switch via argument
# ---------------------------------------------------------------------------

@test "integration: direct switch to marcogvorwerk via argument" {
  git -C "$TEST_DIR" init -q
  run bash -c "cd '${TEST_DIR}' && '${SCRIPT}' marcogvorwerk"
  [ "$status" -eq 0 ]
  local name
  name=$(git -C "$TEST_DIR" config --local user.name)
  [ "$name" = "marcogvorwerk" ]
}

@test "integration: direct switch to marcoguastalli via argument" {
  git -C "$TEST_DIR" init -q
  run bash -c "cd '${TEST_DIR}' && '${SCRIPT}' marcoguastalli"
  [ "$status" -eq 0 ]
  local name
  name=$(git -C "$TEST_DIR" config --local user.name)
  [ "$name" = "marcoguastalli" ]
}

# ---------------------------------------------------------------------------
# --dry-run flag
# ---------------------------------------------------------------------------

@test "integration: --dry-run does not modify git config" {
  git -C "$TEST_DIR" init -q
  run bash -c "cd '${TEST_DIR}' && '${SCRIPT}' --dry-run marcogvorwerk"
  [ "$status" -eq 0 ]
  echo "${output}" | grep -q "dry-run"
  # No user.name should have been written
  run bash -c "cd '${TEST_DIR}' && git config --local user.name 2>&1 || true"
  # Should be empty (exit non-zero from git config means no value set)
  [ -z "${output}" ] || echo "${output}" | grep -qv "marcogvorwerk"
}

# ---------------------------------------------------------------------------
# --help flag
# ---------------------------------------------------------------------------

@test "integration: --help exits 0 and prints usage" {
  run bash -c "'${SCRIPT}' --help"
  [ "$status" -eq 0 ]
  echo "${output}" | grep -qi "usage"
}
