#!/usr/bin/env bash
# Bootstrap this dotfiles checkout on Apple Silicon macOS.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$SCRIPT_DIR"
FLAKE_REF="git+file://$FLAKE_DIR"
SYSTEM_NAME="Matthews-MacBook-Pro"

log() {
  printf '[bootstrap-macos] %s\n' "$*" >&2
}

fail() {
  printf '[bootstrap-macos] ERROR: %s\n' "$*" >&2
  exit 1
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  fail "this bootstrap is only for macOS"
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  fail "this configuration currently targets Apple Silicon (arm64)"
fi

NIX_BIN="$(command -v nix || true)"
if [[ -z "$NIX_BIN" && -x /nix/var/nix/profiles/default/bin/nix ]]; then
  NIX_BIN=/nix/var/nix/profiles/default/bin/nix
fi
[[ -n "$NIX_BIN" ]] || fail "Nix is required; install multi-user Nix first"
command -v brew >/dev/null 2>&1 || fail "Homebrew is required for the six declared signed casks"
command -v sudo >/dev/null 2>&1 || fail "sudo is required for nix-darwin activation"

log "migrating links created by the legacy installer"
DOTFILES_DIR="$SCRIPT_DIR" "$SCRIPT_DIR/lib/migrate-home-manager-links.sh"

log "building the pinned nix-darwin system"
SYSTEM_PATH="$("$NIX_BIN" build \
  "$FLAKE_REF#darwinConfigurations.\"$SYSTEM_NAME\".system" \
  --no-link --print-out-paths)"

backup_etc_file() {
  local target="$1"
  local backup="$target.before-nix-darwin"
  local reply

  if [[ ! -e "$target" || -L "$target" ]]; then
    return
  fi

  [[ ! -e "$backup" ]] || fail "$backup already exists; inspect it before retrying"
  [[ -t 0 ]] || fail "$target must be moved before first activation; rerun interactively"

  printf '%s is an unmanaged file. Preserve it as %s so nix-darwin can manage the original path? [y/N] ' \
    "$target" "$backup" >&2
  read -r reply
  case "$reply" in
    y|Y|yes|YES)
      sudo mv "$target" "$backup"
      ;;
    *)
      fail "left $target unchanged"
      ;;
  esac
}

backup_etc_file /etc/bashrc
backup_etc_file /etc/zshenv

log "activating $SYSTEM_NAME"
sudo "$SYSTEM_PATH/sw/bin/darwin-rebuild" switch \
  --flake "$FLAKE_REF#$SYSTEM_NAME"

log "activation complete; open a new login shell with: exec zsh -l"
