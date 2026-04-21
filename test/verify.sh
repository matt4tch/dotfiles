#!/usr/bin/env bash
#
# Post-install verification. Runs inside a distro container as the `dev` user
# after ./install.sh has executed. Two modes:
#
#   (default)      post-first-install assertions, snapshots current ~/.backup-*
#                  state to /tmp/backups-run1.txt for idempotency comparison.
#   --post-rerun   re-runs every default assertion AND additionally verifies
#                  (a) no new ~/.backup-* files appeared since the snapshot,
#                  (b) preserved paths (~/.codex/skills/.system/marker.txt and
#                      ~/.config/gh/hosts.yml) survived untouched.
#
# Fails fast with `FAIL: <reason>` on the first violation, exit 1.
# On success prints `VERIFY OK (<mode>) on <distro>` and exits 0.

set -euo pipefail

# sesh may land in $HOME/.local/bin depending on the install path taken.
export PATH="$HOME/.local/bin:$PATH"

REPO="$HOME/dotfiles"
BACKUP_SNAPSHOT="/tmp/backups-run1.txt"

mode="default"
case "${1:-}" in
  "")            mode="default" ;;
  --post-rerun)  mode="post-rerun" ;;
  *)             echo "FAIL: unknown argument '$1'" >&2; exit 1 ;;
esac

# ---- Assertion helpers -------------------------------------------------------

fail() { echo "FAIL: $*" >&2; exit 1; }

assert_symlink() {
  local target="$1" expected="$2"
  [ -L "$target" ] || fail "expected symlink at $target (missing or not a symlink)"
  local actual
  actual="$(readlink -f "$target")"
  [ "$actual" = "$expected" ] \
    || fail "symlink $target resolves to $actual, expected $expected"
}

assert_real_dir() {
  local path="$1"
  [ -L "$path" ] && fail "$path must be a real directory, not a symlink"
  [ -d "$path" ] || fail "expected directory at $path"
}

assert_real_file() {
  local path="$1"
  [ -L "$path" ] && fail "$path must be a real file, not a symlink"
  [ -f "$path" ] || fail "expected file at $path"
}

assert_file_exists() {
  local path="$1"
  [ -e "$path" ] || fail "expected file to exist: $path"
}

assert_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "command not on PATH: $1"
}

assert_file_contains() {
  local path="$1" needle="$2"
  [ -f "$path" ] || fail "expected file at $path"
  grep -q -F -- "$needle" "$path" \
    || fail "file $path does not contain expected content: $needle"
}

# ---- Symlink assertions (home-directory dotfiles) ----------------------------

home_dotfiles=(
  .bash_profile
  .bashrc
  .profile
  .zlogin
  .zshrc
  .gitconfig
  .p10k.zsh
  .tmux.conf
  .vimrc
)
for f in "${home_dotfiles[@]}"; do
  assert_symlink "$HOME/$f" "$REPO/$f"
done

# ---- .codex tree (real dirs, per-file symlinks inside) -----------------------

assert_real_dir  "$HOME/.codex"
assert_symlink   "$HOME/.codex/config.toml" "$REPO/.codex/config.toml"
assert_real_dir  "$HOME/.codex/skills"
assert_symlink   "$HOME/.codex/skills/git-usage" "$REPO/.codex/skills/git-usage"

# ---- ~/.config tree ----------------------------------------------------------

assert_real_dir  "$HOME/.config/gh"
assert_symlink   "$HOME/.config/gh/config.yml" "$REPO/gh/config.yml"
assert_symlink   "$HOME/.config/ghostty"       "$REPO/ghostty"
assert_symlink   "$HOME/.config/nvim"          "$REPO/nvim"

# ---- Binaries on PATH --------------------------------------------------------

for bin in zsh nvim tmux fzf rg sesh; do
  assert_cmd "$bin"
done

# ---- Required real directories ----------------------------------------------

assert_real_dir  "$HOME/.oh-my-zsh"
assert_real_dir  "$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
assert_real_dir  "$HOME/.tmux/plugins/tpm"
assert_file_exists "$HOME/.tmux/plugins/tpm/bin/install_plugins"

# ---- tpm plugin dirs ---------------------------------------------------------

tpm_plugin_dir="$HOME/.tmux/plugins"
for plugin in tmux-sensible tmux-resurrect tmux-continuum tmux-thumbs; do
  [ -d "$tpm_plugin_dir/$plugin" ] \
    || fail "missing tpm plugin dir: $tpm_plugin_dir/$plugin"
done
# dracula/tmux clones to either $tpm_plugin_dir/tmux or $tpm_plugin_dir/dracula-tmux
# depending on tpm version — accept whichever shows up.
if [ ! -d "$tpm_plugin_dir/tmux" ] && [ ! -d "$tpm_plugin_dir/dracula-tmux" ]; then
  fail "missing dracula tpm plugin (looked for '$tpm_plugin_dir/tmux' and '$tpm_plugin_dir/dracula-tmux')"
fi

# ---- Mode-specific work ------------------------------------------------------

snapshot_backups() {
  # Snapshot backup files in $HOME's top level (where install.sh's
  # whole-file symlinks produce backups). See contract: idempotent reruns
  # must not create new ~/.backup-* files.
  ls -la "$HOME" 2>/dev/null | grep '\.backup-' | sort > "$BACKUP_SNAPSHOT" || true
}

if [ "$mode" = "default" ]; then
  snapshot_backups
fi

if [ "$mode" = "post-rerun" ]; then
  # (a) No new backups from the second install.
  current="$(ls -la "$HOME" 2>/dev/null | grep '\.backup-' | sort || true)"
  prior="$(cat "$BACKUP_SNAPSHOT" 2>/dev/null || true)"
  if [ "$current" != "$prior" ]; then
    echo "--- expected (run 1 snapshot) ---" >&2
    echo "$prior"  >&2
    echo "--- actual (after run 2) ---"     >&2
    echo "$current" >&2
    fail "post-rerun produced new ~/.backup-* files; install.sh is not idempotent"
  fi

  # (b) Preserved user-managed paths must survive the second install.
  assert_file_contains "$HOME/.codex/skills/.system/marker.txt" "preserved"
  assert_real_file     "$HOME/.config/gh/hosts.yml"
  assert_file_contains "$HOME/.config/gh/hosts.yml" "token=abc"
fi

# ---- Report ------------------------------------------------------------------

distro="unknown"
if [ -r /etc/os-release ]; then
  distro="$(awk -F= '$1=="ID"{gsub(/"/,"",$2); print $2}' /etc/os-release 2>/dev/null || echo unknown)"
fi

echo "VERIFY OK ($mode) on $distro"
