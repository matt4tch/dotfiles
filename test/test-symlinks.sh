#!/usr/bin/env bash
# Focused symlink tests that run on macOS's system Bash 3.2 and Linux.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-symlinks.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

export HOME="$TMP_ROOT/home"
export DOTFILES_DIR="$TMP_ROOT/repo"
export RUN_TS="test-run"
export DRY_RUN=0 SKIP_DEPS=1 SKIP_LINKS=0 CHANGE_SHELL=0

mkdir -p "$HOME" "$DOTFILES_DIR/source-dir"
printf 'source\n' > "$DOTFILES_DIR/source-file"

# shellcheck source=../lib/common.sh
source "$REPO_ROOT/lib/common.sh"
# shellcheck source=../lib/symlinks.sh
source "$REPO_ROOT/lib/symlinks.sh"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

# Absolute and relative links to the right source must both be idempotent.
ln -s "$DOTFILES_DIR/source-file" "$HOME/absolute-link"
link_one "$DOTFILES_DIR/source-file" "$HOME/absolute-link"
[ "$LINK_OK" -eq 1 ] || fail "absolute symlink was not recognized"

mkdir -p "$HOME/nested"
ln -s "../../repo/source-file" "$HOME/nested/relative-link"
link_one "$DOTFILES_DIR/source-file" "$HOME/nested/relative-link"
[ "$LINK_OK" -eq 2 ] || fail "relative symlink was not recognized"

# A wrong link is backed up and replaced.
printf 'other\n' > "$DOTFILES_DIR/other-file"
ln -s "$DOTFILES_DIR/other-file" "$HOME/wrong-link"
link_one "$DOTFILES_DIR/source-file" "$HOME/wrong-link"
[ -L "$HOME/wrong-link.backup-test-run" ] || fail "wrong link was not backed up"
[ "$(_canon "$HOME/wrong-link")" = "$(_canon "$DOTFILES_DIR/source-file")" ] \
  || fail "wrong link was not replaced"

# Conversion of an old whole-directory link must retain ignored user state.
mkdir -p "$DOTFILES_DIR/legacy-skills/.system"
printf 'preserved\n' > "$DOTFILES_DIR/legacy-skills/.system/marker.txt"
ln -s "$DOTFILES_DIR/legacy-skills" "$HOME/legacy-skills"
_convert_symlink_dir_to_real "$HOME/legacy-skills" ".system"
ensure_real_dir "$HOME/legacy-skills"
[ ! -L "$HOME/legacy-skills" ] || fail "legacy directory was not converted"
grep -q preserved "$HOME/legacy-skills/.system/marker.txt" \
  || fail "ignored user state was not preserved"

# Reproduce the repository's older macOS layout and exercise the complete
# Codex/GitHub conversion, including a second idempotent pass.
mkdir -p "$DOTFILES_DIR/.codex/skills/git-usage" "$DOTFILES_DIR/gh"
printf 'config\n' > "$DOTFILES_DIR/.codex/config.toml"
printf 'skill\n' > "$DOTFILES_DIR/.codex/skills/git-usage/SKILL.md"
mkdir -p "$DOTFILES_DIR/.codex/skills/.system"
printf 'system-state\n' > "$DOTFILES_DIR/.codex/skills/.system/marker.txt"
printf 'config\n' > "$DOTFILES_DIR/gh/config.yml"
printf 'token\n' > "$DOTFILES_DIR/gh/hosts.yml"

mkdir -p "$HOME/.codex" "$HOME/.config"
ln -s "$DOTFILES_DIR/.codex/skills" "$HOME/.codex/skills"
ln -s "$DOTFILES_DIR/gh" "$HOME/.config/gh"
link_codex
link_gh

[ ! -L "$HOME/.codex/skills" ] || fail "Codex skills directory was not converted"
[ ! -L "$HOME/.codex/skills/.system" ] || fail "Codex system state became a symlink"
grep -q system-state "$HOME/.codex/skills/.system/marker.txt" \
  || fail "Codex system state was not preserved"
[ ! -L "$HOME/.config/gh" ] || fail "GitHub config directory was not converted"
[ ! -L "$HOME/.config/gh/hosts.yml" ] || fail "GitHub credentials became a symlink"
grep -q token "$HOME/.config/gh/hosts.yml" || fail "GitHub credentials were not preserved"

backups_before="$(find "$HOME" -name '*.backup-*' -print | sort)"
link_codex
link_gh
backups_after="$(find "$HOME" -name '*.backup-*' -print | sort)"
[ "$backups_after" = "$backups_before" ] || fail "rerun created additional backups"

# Dry-run conversion must complete without mutating the old symlink or
# treating entries visible through it as existing destination files.
mkdir -p "$DOTFILES_DIR/dry-source"
printf 'source\n' > "$DOTFILES_DIR/dry-source/config"
ln -s "$DOTFILES_DIR/dry-source" "$HOME/legacy-dir"
DRY_RUN=1
_convert_symlink_dir_to_real "$HOME/legacy-dir"
ensure_real_dir "$HOME/legacy-dir"
link_one "$DOTFILES_DIR/dry-source/config" "$HOME/legacy-dir/config"
[ -L "$HOME/legacy-dir" ] || fail "dry-run mutated the legacy symlink"

printf 'PASS: symlink portability tests\n'
