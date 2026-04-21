#!/usr/bin/env bash
# lib/platform.sh
# OS detection and package-manager dispatch.

# Sets OS_FAMILY to one of: macos, ubuntu, debian, fedora, arch.
# Errors out for anything else.
detect_os() {
  local uname_s
  uname_s="$(uname -s)"
  case "$uname_s" in
    Darwin)
      OS_FAMILY="macos"
      ;;
    Linux)
      if [ ! -r /etc/os-release ]; then
        err "cannot read /etc/os-release; cannot detect Linux distro"
      fi
      # shellcheck disable=SC1091
      . /etc/os-release
      local id="${ID:-}"
      local id_like="${ID_LIKE:-}"
      case "$id" in
        ubuntu) OS_FAMILY="ubuntu" ;;
        debian) OS_FAMILY="debian" ;;
        fedora) OS_FAMILY="fedora" ;;
        arch)   OS_FAMILY="arch" ;;
        *)
          # fall back to ID_LIKE for downstream distros
          case " $id_like " in
            *" debian "*|*" ubuntu "*) OS_FAMILY="debian" ;;
            *" fedora "*|*" rhel "*)   OS_FAMILY="fedora" ;;
            *" arch "*)                OS_FAMILY="arch" ;;
            *)
              err "Unsupported Linux distro: $id. Supported: ubuntu, debian, fedora, arch."
              ;;
          esac
          ;;
      esac
      ;;
    *)
      err "Unsupported OS: $uname_s"
      ;;
  esac
  export OS_FAMILY
  log "detected OS family: $OS_FAMILY"
}

# On Linux, verify passwordless sudo is usable. Called before any apt/dnf/pacman.
check_sudo_linux() {
  if [ "$OS_FAMILY" = "macos" ]; then
    return 0
  fi
  if ! has_cmd sudo; then
    err "sudo not found. This script needs sudo on Linux."
  fi
  if ! sudo -n true 2>/dev/null; then
    err "This script needs passwordless sudo on Linux. Configure it and retry."
  fi
}

# Refresh the package index (no-op on macos).
pkg_refresh() {
  case "$OS_FAMILY" in
    macos)
      : ;;
    ubuntu|debian)
      run_cmd sudo apt-get update
      ;;
    fedora)
      # check-update returns 100 when updates available — not an error.
      if (( DRY_RUN == 1 )); then
        log "DRY-RUN: sudo dnf -y check-update || true"
      else
        sudo dnf -y check-update || true
      fi
      ;;
    arch)
      run_cmd sudo pacman -Sy --noconfirm
      ;;
    *)
      err "pkg_refresh: unknown OS_FAMILY=$OS_FAMILY"
      ;;
  esac
}

# pkg_install <pkg...> — install packages using the platform's package manager.
# All package managers are invoked non-interactively and with idempotency
# ("needed" / preinstalled-is-fine semantics).
pkg_install() {
  (( $# > 0 )) || return 0
  case "$OS_FAMILY" in
    macos)
      run_cmd brew install "$@"
      ;;
    ubuntu|debian)
      run_cmd sudo apt-get install -y "$@"
      ;;
    fedora)
      run_cmd sudo dnf install -y "$@"
      ;;
    arch)
      run_cmd sudo pacman -S --needed --noconfirm "$@"
      ;;
    *)
      err "pkg_install: unknown OS_FAMILY=$OS_FAMILY"
      ;;
  esac
}
