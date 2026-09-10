#!/usr/bin/env bash
# Convert links created by the legacy installer into paths Home Manager can own.

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

log() {
  printf '[migrate-home-manager-links] %s\n' "$*" >&2
}

remove_repo_link() {
  local target="$1"
  local expected="${2%/}"
  local actual

  [[ -L "$target" ]] || return 0
  actual="$(readlink "$target")"
  actual="${actual%/}"
  if [[ "$actual" != "$expected" ]]; then
    log "leaving unrelated symlink unchanged: $target -> $actual"
    return 0
  fi

  unlink "$target"
  log "removed legacy symlink: $target -> $expected"
}

convert_stateful_directory_link() {
  local target="$1"
  local expected="${2%/}"
  local preserved_relative="$3"
  local actual preserved_source preserved_target

  [[ -L "$target" ]] || return 0
  actual="$(readlink "$target")"
  actual="${actual%/}"
  if [[ "$actual" != "$expected" ]]; then
    log "leaving unrelated directory symlink unchanged: $target -> $actual"
    return 0
  fi

  preserved_source="$expected/$preserved_relative"
  preserved_target="$target/$preserved_relative"
  unlink "$target"
  mkdir -p "$target"

  if [[ -e "$preserved_source" || -L "$preserved_source" ]]; then
    if [[ -e "$preserved_target" || -L "$preserved_target" ]]; then
      log "refusing to overwrite preserved state: $preserved_target"
      exit 1
    fi
    mkdir -p "$(dirname "$preserved_target")"
    mv "$preserved_source" "$preserved_target"
    log "preserved runtime state at: $preserved_target"
  fi

  log "converted legacy directory symlink to a real directory: $target"
}

# These parent directories contain state that must remain outside the Nix
# store. Convert them before managing the version-controlled children.
convert_stateful_directory_link \
  "$HOME/.codex/skills" "$DOTFILES_DIR/.codex/skills" ".system"
convert_stateful_directory_link \
  "$HOME/.config/gh" "$DOTFILES_DIR/gh" "hosts.yml"

while IFS='|' read -r target source; do
  [[ -n "$target" ]] || continue
  remove_repo_link "$HOME/$target" "$DOTFILES_DIR/$source"
done <<'LINKS'
.bash_profile|.bash_profile
.bashrc|.bashrc
.profile|.profile
.zlogin|.zlogin
.zshrc|.zshrc
.gitconfig|.gitconfig
.p10k.zsh|.p10k.zsh
.tmux.conf|.tmux.conf
.vimrc|.vimrc
.codex/AGENTS.md|.codex/AGENTS.md
.codex/config.toml|.codex/config.toml
.codex/hooks.json|.codex/hooks.json
.codex/hooks|.codex/hooks
.config/gh/config.yml|gh/config.yml
.config/ghostty|ghostty
.config/nvim|nvim
LINKS

log "legacy-link migration complete"
