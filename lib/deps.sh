#!/usr/bin/env bash
# lib/deps.sh
# Per-dependency install functions. Every function is idempotent: it detects
# whether the dep is already present and returns 0 early if so.

# --- Homebrew (macOS) ------------------------------------------------------
install_brew() {
  [ "$OS_FAMILY" = "macos" ] || return 0
  if has_cmd brew; then
    log "brew: already installed"
    return 0
  fi
  log "installing Homebrew"
  run_sh '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  # Make brew visible for the rest of this script (both Apple Silicon and
  # Intel layouts).
  if (( DRY_RUN == 0 )); then
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
}

# --- Base OS packages + toolchain -----------------------------------------
install_pkg_prereqs() {
  log "installing package prerequisites"
  case "$OS_FAMILY" in
    macos)
      install_brew
      pkg_install git zsh tmux
      # git & curl ship with Xcode CLT on macOS; assume present. No apt.
      ;;
    ubuntu|debian)
      pkg_refresh
      pkg_install git curl zsh tmux unzip ca-certificates build-essential
      ;;
    fedora)
      pkg_refresh
      pkg_install git curl zsh tmux unzip ca-certificates @development-tools
      ;;
    arch)
      pkg_refresh
      pkg_install git curl zsh tmux unzip ca-certificates base-devel
      ;;
    *)
      err "install_pkg_prereqs: unknown OS_FAMILY=$OS_FAMILY"
      ;;
  esac
}

# --- Oh My Zsh -------------------------------------------------------------
install_omz() {
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log "oh-my-zsh: already installed"
    return 0
  fi
  log "installing oh-my-zsh (unattended, keep-zshrc)"
  # --unattended disables chsh and the post-install "try zsh now" prompt.
  # --keep-zshrc is critical: our .zshrc is owned by this repo and symlinked.
  run_sh 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc'
}

# --- Powerlevel10k theme ---------------------------------------------------
install_p10k() {
  local dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [ -d "$dir" ]; then
    log "powerlevel10k: already installed"
    return 0
  fi
  log "installing powerlevel10k"
  run_cmd git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$dir"
}

install_zsh_stack() {
  install_omz
  install_p10k
}

# --- fzf -------------------------------------------------------------------
install_fzf() {
  if has_cmd fzf; then
    log "fzf: already installed"
  else
    pkg_install fzf
  fi
  # On macOS, run brew's key-bindings installer once (non-interactive, no rc
  # rewrites). Skip if brew isn't available (e.g. dry-run before brew install).
  if [ "$OS_FAMILY" = "macos" ] && has_cmd brew; then
    local prefix
    prefix="$(brew --prefix 2>/dev/null || printf '')"
    if [ -n "$prefix" ] && [ -x "$prefix/opt/fzf/install" ]; then
      # --all: install key bindings + completion; --no-update-rc: don't touch
      # our .zshrc (we already wire it up via the repo).
      run_cmd "$prefix/opt/fzf/install" --all --no-update-rc
    fi
  fi
}

install_ripgrep() {
  if has_cmd rg; then
    log "ripgrep: already installed"
    return 0
  fi
  pkg_install ripgrep
}

install_neovim() {
  if has_cmd nvim; then
    log "neovim: already installed"
    return 0
  fi
  pkg_install neovim
}

install_tmux() {
  if has_cmd tmux; then
    log "tmux: already installed"
    return 0
  fi
  pkg_install tmux
}

# --- nvm -------------------------------------------------------------------
# Detection covers: brew-installed (macOS), git-cloned to ~/.nvm (Linux
# convention), and the user's existing export of $NVM_DIR.
_nvm_present() {
  if [ -n "${NVM_DIR:-}" ] && [ -s "$NVM_DIR/nvm.sh" ]; then
    return 0
  fi
  if [ -s "$HOME/.nvm/nvm.sh" ]; then
    return 0
  fi
  if [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] || [ -s "/usr/local/opt/nvm/nvm.sh" ]; then
    return 0
  fi
  return 1
}

install_nvm() {
  if _nvm_present; then
    log "nvm: already installed"
    return 0
  fi
  case "$OS_FAMILY" in
    macos)
      pkg_install nvm
      # Homebrew's nvm requires the user to create their own $NVM_DIR.
      ensure_dir "$HOME/.nvm"
      ;;
    ubuntu|debian|fedora|arch)
      log "installing nvm via upstream install.sh (PROFILE=/dev/null so it doesn't edit our rc)"
      # PROFILE=/dev/null prevents nvm's installer from appending source lines
      # to ~/.zshrc/~/.bashrc — those are owned by this repo.
      run_sh 'curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | PROFILE=/dev/null bash'
      ;;
  esac
}

# --- sesh (tmux session switcher) -----------------------------------------
# Resolves the latest release tag by following the GitHub "latest" redirect.
# Uses the release tarball to avoid needing a Go toolchain.
_sesh_download_release() {
  local arch tmpdir latest_url version asset url
  case "$(uname -m)" in
    x86_64|amd64)   arch="amd64" ;;
    aarch64|arm64)  arch="arm64" ;;
    *) warn "sesh: unsupported architecture $(uname -m)"; return 1 ;;
  esac
  # curl -sIL follows redirects; %{url_effective} returns the final URL, which
  # is .../releases/tag/vX.Y.Z.
  latest_url="$(curl -fsSIL -o /dev/null -w '%{url_effective}' \
    'https://github.com/joshmedeski/sesh/releases/latest' 2>/dev/null || true)"
  version="${latest_url##*/}"
  if [ -z "$version" ] || [ "$version" = "latest" ]; then
    warn "sesh: could not resolve latest release tag"
    return 1
  fi
  asset="sesh_${version#v}_linux_${arch}.tar.gz"
  url="https://github.com/joshmedeski/sesh/releases/download/${version}/${asset}"
  tmpdir="$(mktemp -d)"
  log "sesh: downloading $url"
  if (( DRY_RUN == 1 )); then
    log "DRY-RUN: curl -fsSL -o $tmpdir/sesh.tar.gz $url"
    log "DRY-RUN: tar -xzf $tmpdir/sesh.tar.gz -C $tmpdir"
    log "DRY-RUN: install -m 0755 $tmpdir/sesh $HOME/.local/bin/sesh"
    rm -rf "$tmpdir"
    ensure_dir "$HOME/.local/bin"
    return 0
  fi
  if ! curl -fsSL -o "$tmpdir/sesh.tar.gz" "$url"; then
    warn "sesh: release tarball download failed ($url)"
    rm -rf "$tmpdir"
    return 1
  fi
  if ! tar -xzf "$tmpdir/sesh.tar.gz" -C "$tmpdir"; then
    warn "sesh: tarball extract failed"
    rm -rf "$tmpdir"
    return 1
  fi
  ensure_dir "$HOME/.local/bin"
  if [ ! -f "$tmpdir/sesh" ]; then
    warn "sesh: extracted tarball does not contain 'sesh' binary"
    rm -rf "$tmpdir"
    return 1
  fi
  mv -- "$tmpdir/sesh" "$HOME/.local/bin/sesh"
  chmod +x "$HOME/.local/bin/sesh"
  rm -rf "$tmpdir"
  return 0
}

install_sesh() {
  if has_cmd sesh; then
    log "sesh: already installed"
    return 0
  fi
  case "$OS_FAMILY" in
    macos)
      pkg_install sesh
      ;;
    ubuntu|debian|fedora|arch)
      if _sesh_download_release; then
        log "sesh: installed to ~/.local/bin/sesh"
      elif has_cmd go; then
        log "sesh: release download failed; falling back to 'go install'"
        run_cmd go install github.com/joshmedeski/sesh/v2@latest
      else
        err "sesh: release tarball failed and 'go' is not installed"
      fi
      if ! path_in "$HOME/.local/bin" "$PATH"; then
        warn "\$HOME/.local/bin is not on \$PATH; add it to your shell rc to pick up sesh"
      fi
      ;;
  esac
}

# --- tmux plugin manager + plugins ----------------------------------------
install_tpm() {
  local dir="$HOME/.tmux/plugins/tpm"
  if [ -d "$dir" ]; then
    log "tpm: already installed"
    return 0
  fi
  log "installing tpm"
  run_cmd git clone https://github.com/tmux-plugins/tpm "$dir"
}

# Runs after .tmux.conf is symlinked so tpm can read the plugin list from it.
install_tpm_plugins() {
  local tpm_bin="$HOME/.tmux/plugins/tpm/bin/install_plugins"
  if [ ! -x "$tpm_bin" ]; then
    warn "tpm install_plugins not found at $tpm_bin; skipping plugin install"
    return 0
  fi
  if [ ! -e "$HOME/.tmux.conf" ]; then
    warn "~/.tmux.conf not linked yet; skipping plugin install"
    return 0
  fi
  log "installing tpm plugins (dracula, tmux-sensible, tmux-resurrect, tmux-continuum, tmux-thumbs)"
  run_cmd "$tpm_bin"
}

# --- Aggregate: install every tool the zsh/tmux configs reference ---------
install_tools() {
  install_fzf
  install_ripgrep
  install_neovim
  install_tmux
  install_nvm
}

# --- Optional: change login shell to zsh on Linux -------------------------
change_shell_to_zsh() {
  if [ "$OS_FAMILY" = "macos" ]; then
    log "change-shell: macOS login shell is already zsh; skipping"
    return 0
  fi
  if ! has_cmd zsh; then
    warn "change-shell: zsh not installed; skipping"
    return 0
  fi
  local zsh_path current
  zsh_path="$(command -v zsh)"
  current="${SHELL:-}"
  if [ "$current" = "$zsh_path" ]; then
    log "change-shell: already zsh ($zsh_path)"
    return 0
  fi
  log "changing login shell to zsh ($zsh_path) for $USER"
  run_cmd sudo chsh -s "$zsh_path" "$USER"
}
