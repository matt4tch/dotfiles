#!/usr/bin/env bash
# install.sh — bootstrap a fresh machine from this dotfiles repo.
#
# Symlinks every tracked dotfile into place (with timestamped backups of
# anything it displaces), and installs the missing dependencies referenced
# by those configs: Homebrew on macOS, apt/dnf/pacman on Linux, Oh My Zsh,
# Powerlevel10k, fzf, ripgrep, neovim, tmux, nvm, sesh, tpm + plugins.
#
# Idempotent: running twice is safe — nothing is re-clobbered.
#
# Usage: ./install.sh [--dry-run] [--skip-deps] [--skip-links] [--change-shell]
#        ./install.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES_DIR="$SCRIPT_DIR"
export RUN_TS="$(date +%Y%m%d-%H%M%S)"

# --- Flag defaults ---------------------------------------------------------
DRY_RUN=0
SKIP_DEPS=0
SKIP_LINKS=0
CHANGE_SHELL=0

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Bootstrap a fresh machine from this dotfiles repo. Detects the OS, installs
any missing dependencies, then symlinks every dotfile into $HOME (with
timestamped backups of anything it would displace). Safe to rerun.

Options:
  --dry-run         Preview every action. No filesystem changes; every mutation
                    is logged as "DRY-RUN: <command>".
  --skip-deps       Skip dependency installation. Only run the symlink pass
                    (and tpm plugin install if applicable).
  --skip-links      Skip the symlink pass. Only install / update dependencies.
  --change-shell    On Linux, chsh the current user's login shell to zsh.
                    No-op on macOS (already zsh). Off by default so Docker
                    tests don't block on it.
  -h, --help        Print this help and exit.

Environment:
  The repo root is derived from this script's location; you can invoke it as
  `./install.sh` from the repo or `bash /abs/path/to/install.sh` from anywhere.

Preserved paths (never touched, even on reinstall):
  ~/.codex/skills/.system/     (managed outside this repo)
  ~/.config/gh/hosts.yml       (contains auth tokens)
EOF
}

# --- Parse flags -----------------------------------------------------------
while (( $# > 0 )); do
  case "$1" in
    --dry-run)      DRY_RUN=1 ;;
    --skip-deps)    SKIP_DEPS=1 ;;
    --skip-links)   SKIP_LINKS=1 ;;
    --change-shell) CHANGE_SHELL=1 ;;
    -h|--help)      usage; exit 0 ;;
    --)             shift; break ;;
    *)
      printf 'install.sh: unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

export DRY_RUN SKIP_DEPS SKIP_LINKS CHANGE_SHELL

# --- Source helpers --------------------------------------------------------
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/platform.sh
source "$SCRIPT_DIR/lib/platform.sh"
# shellcheck source=lib/deps.sh
source "$SCRIPT_DIR/lib/deps.sh"
# shellcheck source=lib/symlinks.sh
source "$SCRIPT_DIR/lib/symlinks.sh"

# --- Banner ----------------------------------------------------------------
log "dotfiles install starting"
log "repo:        $DOTFILES_DIR"
log "run ts:      $RUN_TS"
if (( DRY_RUN == 1 )); then
  log "mode:        DRY RUN (no filesystem changes)"
fi
if (( SKIP_DEPS == 1 )); then log "mode:        skipping dependency install"; fi
if (( SKIP_LINKS == 1 )); then log "mode:        skipping symlink pass"; fi

# --- Orchestration ---------------------------------------------------------
detect_os

if (( SKIP_DEPS == 0 )); then
  check_sudo_linux
  install_pkg_prereqs
  install_zsh_stack
  install_tools
  install_sesh
  install_tpm
fi

if (( SKIP_LINKS == 0 )); then
  link_all
fi

if (( SKIP_DEPS == 0 )); then
  # Must run AFTER link_all so ~/.tmux.conf exists for tpm to read.
  install_tpm_plugins
fi

if (( CHANGE_SHELL == 1 )); then
  change_shell_to_zsh
fi

# --- Summary ---------------------------------------------------------------
print_link_summary
if (( DRY_RUN == 1 )); then
  log "dry run complete — no changes were made"
else
  log "install complete"
fi
