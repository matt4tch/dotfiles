#!/usr/bin/env bash
# lib/common.sh
# Shared helpers for install.sh. Sourced, not executed. Assumes `set -euo
# pipefail` is already active in the caller.

# --- Flags / globals expected from the caller -------------------------------
# DRY_RUN, SKIP_DEPS, SKIP_LINKS, CHANGE_SHELL — set to 0/1 by install.sh
# DOTFILES_DIR — absolute path to the repo root; set by install.sh
# RUN_TS — single run-level timestamp; set once here if unset
: "${DRY_RUN:=0}"
: "${SKIP_DEPS:=0}"
: "${SKIP_LINKS:=0}"
: "${CHANGE_SHELL:=0}"
: "${DOTFILES_DIR:?DOTFILES_DIR must be set by install.sh}"
: "${RUN_TS:=$(date +%Y%m%d-%H%M%S)}"
export DOTFILES_DIR RUN_TS

# --- Logging ---------------------------------------------------------------
# Everything goes to stderr so stdout stays clean for future machine-readable
# output if we ever need it.
log() {
  printf '[install] %s\n' "$*" >&2
}

# Red error + exit 1. Only colorize when stderr is a tty.
err() {
  if [ -t 2 ]; then
    printf '\033[31m[install] ERROR: %s\033[0m\n' "$*" >&2
  else
    printf '[install] ERROR: %s\n' "$*" >&2
  fi
  exit 1
}

warn() {
  if [ -t 2 ]; then
    printf '\033[33m[install] WARN: %s\033[0m\n' "$*" >&2
  else
    printf '[install] WARN: %s\n' "$*" >&2
  fi
}

# --- Command helpers -------------------------------------------------------
has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

require_cmd() {
  has_cmd "$1" || err "required command not found: $1"
}

# run_cmd <cmd> [args...] — execute, or in dry-run just log the command.
# Used for every mutating action (ln, mv, mkdir, package installs, git clone).
run_cmd() {
  if (( DRY_RUN == 1 )); then
    log "DRY-RUN: $*"
  else
    "$@"
  fi
}

# run_sh <shell-string> — same as run_cmd but for pipelines / redirects that
# need a shell. In dry-run, logs the literal string.
run_sh() {
  if (( DRY_RUN == 1 )); then
    log "DRY-RUN: sh -c '$*'"
  else
    sh -c "$*"
  fi
}

# ensure_dir <path> — mkdir -p (or log in dry-run). Safe to call repeatedly.
ensure_dir() {
  local dir="$1"
  if [ -d "$dir" ] && [ ! -L "$dir" ]; then
    return 0
  fi
  run_cmd mkdir -p "$dir"
}

# path_in <needle> <path-string> — return 0 if $needle appears as a PATH entry.
path_in() {
  case ":$2:" in
    *":$1:"*) return 0 ;;
    *) return 1 ;;
  esac
}
