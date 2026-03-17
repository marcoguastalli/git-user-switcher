# git-user-switcher

A bash script to switch the local git `user.name` / `user.email` configuration for the current repository and re-authenticate with the GitHub CLI (`gh`).

It manages **local** repository configuration only — global git config is never touched.

---

## Requirements

- macOS (tested on Darwin 24)
- [`git`](https://git-scm.com/)
- [`gh`](https://cli.github.com/) — GitHub CLI

---

## Installation

Copy the script to `/usr/local/bin` so it is available system-wide without a path prefix:

```bash
cp githubuserswitcher.sh /usr/local/bin/githubuserswitcher
chmod +x /usr/local/bin/githubuserswitcher
```

Verify:

```bash
which githubuserswitcher
# → /usr/local/bin/githubuserswitcher
```

### Alternative: user-local install (no sudo)

```bash
mkdir -p ~/.local/bin
cp githubuserswitcher.sh ~/.local/bin/githubuserswitcher
chmod +x ~/.local/bin/githubuserswitcher
```

Add to `~/.zshrc` if not already present:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

---

## Usage

```
githubuserswitcher [OPTIONS] [USERNAME]
```

### Options

| Flag | Description |
|------|-------------|
| `--dry-run` | Show what would be done without making any changes |
| `--help` | Show usage and exit |

### Arguments

| Argument | Description |
|----------|-------------|
| `USERNAME` | Directly switch to a user without the interactive prompt (`marcogvorwerk` or `marcoguastalli`) |

---

## Use cases

### 1. Not inside a git repository

```
$ githubuserswitcher
This folder is not a git repository.
```

Exits `0`.

---

### 2. Git repository with no local user config

```
$ githubuserswitcher

No git user configuration found in this repository. Add one? (y/n)
```

**Answer `n`:**
```
Cheers
```
Exits `0`.

**Answer `y`:**
```
Select a user:
  1) marcogvorwerk
  2) marcoguastalli
  3) Cancel

Enter number [1-3]:
```

Selecting a user runs:
```bash
git config --local user.name  "<user>"
git config --local user.email "<user>"
gh auth login
gh auth status
```

Output:
```
New git configuration:
  user.name  = marcogvorwerk
  user.email = marcogvorwerk
```
Exits `0`.

Selecting **Cancel** exits `1`.

---

### 3. Git repository with existing local user config

```
$ githubuserswitcher

Current git configuration:
  user.name  = marcogvorwerk
  user.email = marcogvorwerk
[gh auth status output]

Change it? (y/n)
```

**Answer `n`:**
```
Cheers
```
Exits `0`.

**Answer `y`:** shows the user selection menu (same as above). On success:
```
Git user switched to:
  user.name  = marcoguastalli
  user.email = marcoguastalli
```
Exits `0`.

---

### 4. Direct switch (no prompt)

```bash
githubuserswitcher marcogvorwerk
githubuserswitcher marcoguastalli
```

Applies the config and runs `gh auth login` immediately. Output:
```
Git user switched to:
  user.name  = marcogvorwerk
  user.email = marcogvorwerk
```
Exits `0`. Exits `1` if the username is not in the configured list.

---

### 5. Dry run

```bash
githubuserswitcher --dry-run marcogvorwerk
```

Prints what would be executed without making any changes:
```
[dry-run] Would run: git config --local user.name "marcogvorwerk"
[dry-run] Would run: git config --local user.email "marcogvorwerk"
[dry-run] Would run: gh auth login
[dry-run] Would run: gh auth status
```
Exits `0`.

Can be combined with interactive mode:
```bash
githubuserswitcher --dry-run
```

---

## Exit codes

| Code | Meaning |
|------|---------|
| `0` | Success or no action needed |
| `1` | User selection invalid or cancelled |
| `2` | Runtime error (missing dependency, unknown flag) |

---

## Configuration

Users are hardcoded in the script as parallel arrays:

```bash
USER_NAMES=(marcogvorwerk marcoguastalli)
USER_EMAILS=(marcogvorwerk marcoguastalli)
```

The interactive selection menu is generated dynamically from these arrays — adding a new user only requires appending to both arrays.

---

## Safety

- `set -euo pipefail` is active throughout the script
- Only `git config --local` is ever written — global config is never modified
- `gh auth login` and `gh auth status` failures are non-fatal (`|| true`)
- Missing `git` or `gh` binaries are detected before any action and exit `2`

---

## Tests

Tests use [BATS](https://github.com/bats-core/bats-core) (Bash Automated Testing System).

### Install BATS (macOS)

```bash
brew install bats-core
```

### Run all tests

```bash
bats tests/unit/user_config_tests.bats \
     tests/integration/repo_switch_tests.bats \
     tests/regression/edge_cases.bats
```

### Test structure

```
tests/
├── unit/
│   └── user_config_tests.bats     # Internal functions: detect_git_repo,
│                                  # read_git_config, list_users,
│                                  # apply_user_config, resolve_username
├── integration/
│   └── repo_switch_tests.bats     # End-to-end flows against real git repos
├── regression/
│   └── edge_cases.bats            # Edge cases and failure scenarios
└── fixtures/
    ├── repo_with_config/
    ├── repo_without_config/
    └── non_git_directory/
```

### What is tested

**Unit tests** — each function in isolation, inside a `mktemp` temporary directory:
- `detect_git_repo` inside and outside a git repo
- `read_git_config` with and without existing config
- `list_users` output format and content
- `apply_user_config` for each user index, and dry-run no-op
- `resolve_username` for valid and invalid usernames

**Integration tests** — full script execution with real `git init`:
- Non-git directory → exits 0
- No config + answer no → exits 0, Cheers
- No config + answer yes + select user → git config written correctly
- No config + cancel → exits 1
- Existing config + answer no → exits 0, Cheers
- Existing config + switch user → git config updated
- Direct argument switch (`marcogvorwerk`, `marcoguastalli`)
- `--dry-run` does not write config
- `--help` exits 0

**Regression tests** — failure scenarios:
- Invalid index (out of range) → exits 1
- Zero index → exits 1
- Non-numeric input → exits 1
- Cancel from existing-config flow → exits 1
- Missing `git` binary → exits 2
- Missing `gh` binary → exits 2
- Non-git directory → exits 0 (not 2)
- Unknown username argument → exits 1
- Unknown flag → exits 2
- `--dry-run` with existing config does not overwrite
- Script never modifies global git config
