#!/usr/bin/env bats
# Regression tests – edge cases and failure scenarios.

SCRIPT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)/githubuserswitcher.sh"

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
  TEST_DIR=$(mktemp -d)
  GH_STUB_DIR=$(mktemp -d)
  cat >"${GH_STUB_DIR}/gh" <<'STUB'
#!/usr/bin/env bash
echo "[gh-stub] $*"
exit 0
STUB
  chmod +x "${GH_STUB_DIR}/gh"
  export PATH="${GH_STUB_DIR}:${PATH}"
}

teardown() {
  rm -rf "$TEST_DIR" "$GH_STUB_DIR"
}

# ---------------------------------------------------------------------------
# Invalid user index (out of range)
# ---------------------------------------------------------------------------

@test "regression: invalid selection index → exits 1" {
  git -C "$TEST_DIR" init -q
  # Answer: y to add config, then 99 (out of range)
  run bash -c "printf 'y\n99\n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 1 ]
}

@test "regression: zero selection index → exits 1" {
  git -C "$TEST_DIR" init -q
  run bash -c "printf 'y\n0\n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 1 ]
}

@test "regression: non-numeric selection → exits 1" {
  git -C "$TEST_DIR" init -q
  run bash -c "printf 'y\nabc\n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Cancel selection (last option)
# ---------------------------------------------------------------------------

@test "regression: cancel from existing config flow → exits 1" {
  git -C "$TEST_DIR" init -q
  git -C "$TEST_DIR" config --local user.name  "marcogvorwerk"
  git -C "$TEST_DIR" config --local user.email "marcogvorwerk"
  # Answer: y to change, then last option (3) = Cancel
  run bash -c "printf 'y\n3\n' | (cd '${TEST_DIR}' && '${SCRIPT}')"
  [ "$status" -eq 1 ]
  echo "${output}" | grep -qi "cancel"
}

# ---------------------------------------------------------------------------
# Missing git binary
# ---------------------------------------------------------------------------

@test "regression: missing git binary → exits 2 with error message" {
  # Use env -i to start with an empty environment so no git binary is on PATH.
  # Only /bin is included (provides bash); GH_STUB_DIR provides gh.
  local no_git_dir
  no_git_dir=$(mktemp -d)
  cp "${GH_STUB_DIR}/gh" "${no_git_dir}/gh"
  run env -i PATH="${no_git_dir}:/bin" HOME="${HOME}" "${SCRIPT}"
  rm -rf "$no_git_dir"
  [ "$status" -eq 2 ]
  echo "${output}" | grep -qi "not installed"
}

# ---------------------------------------------------------------------------
# Missing gh binary
# ---------------------------------------------------------------------------

@test "regression: missing gh binary → exits 2 with error message" {
  # Build a PATH that has git but NOT gh.
  local no_gh_dir
  no_gh_dir=$(mktemp -d)
  # Symlink real git into the isolated dir
  ln -s "$(command -v git)" "${no_gh_dir}/git"
  run bash -c "PATH='${no_gh_dir}:/bin:/usr/bin' '${SCRIPT}'"
  rm -rf "$no_gh_dir"
  [ "$status" -eq 2 ]
  echo "${output}" | grep -qi "not installed"
}

# ---------------------------------------------------------------------------
# Not a git repo → exit 0 (not exit 2)
# ---------------------------------------------------------------------------

@test "regression: non-git directory exits 0 not 2" {
  run bash -c "cd '${TEST_DIR}' && '${SCRIPT}'"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Unknown direct argument
# ---------------------------------------------------------------------------

@test "regression: unknown username argument → exits 1" {
  git -C "$TEST_DIR" init -q
  run bash -c "cd '${TEST_DIR}' && '${SCRIPT}' unknown_user_xyz"
  [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Unknown flag
# ---------------------------------------------------------------------------

@test "regression: unknown flag → exits 2" {
  run bash -c "'${SCRIPT}' --unknown-flag"
  [ "$status" -eq 2 ]
}

# ---------------------------------------------------------------------------
# Dry-run does not touch git config
# ---------------------------------------------------------------------------

@test "regression: dry-run with existing config does not overwrite" {
  git -C "$TEST_DIR" init -q
  git -C "$TEST_DIR" config --local user.name  "marcogvorwerk"
  git -C "$TEST_DIR" config --local user.email "marcogvorwerk"
  run bash -c "cd '${TEST_DIR}' && '${SCRIPT}' --dry-run marcoguastalli"
  [ "$status" -eq 0 ]
  local name
  name=$(git -C "$TEST_DIR" config --local user.name)
  # Should still be the old user
  [ "$name" = "marcogvorwerk" ]
}

# ---------------------------------------------------------------------------
# Global config is NOT touched
# ---------------------------------------------------------------------------

@test "regression: script does not modify global git config" {
  git -C "$TEST_DIR" init -q
  local before_global
  before_global=$(git config --global user.name 2>/dev/null || echo "")

  run bash -c "cd '${TEST_DIR}' && '${SCRIPT}' marcogvorwerk"
  [ "$status" -eq 0 ]

  local after_global
  after_global=$(git config --global user.name 2>/dev/null || echo "")
  [ "$before_global" = "$after_global" ]
}
