#!/usr/bin/env bash
# lib/symlinks.sh
# The symlink state machine and the per-category link functions.

# --- Run-level counters for the final summary ------------------------------
LINK_CREATED=0
LINK_OK=0
LINK_REPLACED=0
LINK_BACKED_UP=0
# Keep an empty sentinel because Bash 3.2 treats an empty-array expansion as
# an unbound variable under set -u.
DRY_RUN_CONVERTED_DIRS=("")

_inc() {
  # Safe increment under `set -e`: ((x++)) returns the old value, and when
  # the old value is 0 that expression is "false" and set -e aborts.
  local __var="$1"
  printf -v "$__var" '%d' "$((${!__var} + 1))"
}

# Home-directory whole-file dotfiles (symlinked directly under $HOME).
HOME_DOTFILES=(
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

# backup_name <path> — return ${path}.backup-${RUN_TS}, adding .1/.2/... if
# a previous call already produced that suffix this run.
backup_name() {
  local target="$1"
  local base="${target}.backup-${RUN_TS}"
  local candidate="$base"
  local n=1
  # Use -e || -L so we also notice dangling symlinks in the backup slot.
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="${base}.${n}"
    n=$((n + 1))
  done
  printf '%s' "$candidate"
}

# Resolve a path to its canonical absolute form without readlink -f, which is
# unavailable on macOS. Intermediate directory symlinks are resolved by
# pwd -P; the loop handles a symlink in the final path component.
_canon() {
  local path="$1" dest parent base hops=0

  while [ -L "$path" ]; do
    dest="$(readlink "$path" 2>/dev/null)" || break
    case "$dest" in
      /*) path="$dest" ;;
      *)  path="$(dirname "$path")/$dest" ;;
    esac
    hops=$((hops + 1))
    if [ "$hops" -gt 40 ]; then
      printf '%s' "$1"
      return 1
    fi
  done

  parent="$(dirname "$path")"
  base="$(basename "$path")"
  if [ -d "$parent" ]; then
    printf '%s/%s' "$(cd "$parent" && pwd -P)" "$base"
  else
    printf '%s' "$path"
  fi
}

# Pretty-print a path with $HOME collapsed to ~ for logs.
_prettify() {
  local p="$1"
  case "$p" in
    "$HOME"/*) printf '~%s' "${p#"$HOME"}" ;;
    "$HOME")   printf '~' ;;
    *)         printf '%s' "$p" ;;
  esac
}

# link_one <src> <target>
#
# Idempotent symlink installer. See install design §5 for the state table.
# In dry-run mode every mutation is logged but nothing is written.
link_one() {
  local src="$1"
  local target="$2"

  if [ ! -e "$src" ] && [ ! -L "$src" ]; then
    err "link_one: source does not exist: $src"
  fi

  local parent
  parent="$(dirname -- "$target")"
  ensure_dir "$parent"

  local pretty_target pretty_src
  pretty_target="$(_prettify "$target")"
  pretty_src="$(_prettify "$src")"

  if (( DRY_RUN == 1 )); then
    local converted
    for converted in "${DRY_RUN_CONVERTED_DIRS[@]}"; do
      [ -n "$converted" ] || continue
      case "$target" in
        "$converted"/*)
          run_cmd ln -s -- "$src" "$target"
          log "symlink: $pretty_target -> $pretty_src (created after directory conversion)"
          _inc LINK_CREATED
          return 0
          ;;
      esac
    done
  fi

  if [ -L "$target" ]; then
    # Target is a symlink. Is it pointing where we want?
    if [ -e "$target" ] && [ "$(_canon "$target")" = "$(_canon "$src")" ]; then
      log "symlink: $pretty_target -> $pretty_src (already linked)"
      _inc LINK_OK
      return 0
    fi
    # Wrong symlink (or dangling) — back it up and re-link.
    local old_dest backup
    old_dest="$(readlink -- "$target" 2>/dev/null || printf '<unreadable>')"
    backup="$(backup_name "$target")"
    run_cmd mv -- "$target" "$backup"
    run_cmd ln -s -- "$src" "$target"
    log "symlink: $pretty_target -> $pretty_src (replaced; old symlink to '$old_dest' -> $(_prettify "$backup"))"
    _inc LINK_REPLACED
    return 0
  fi

  if [ -e "$target" ]; then
    # Real file or real directory.
    local kind="file"
    [ -d "$target" ] && kind="dir"
    local backup
    backup="$(backup_name "$target")"
    run_cmd mv -- "$target" "$backup"
    run_cmd ln -s -- "$src" "$target"
    log "symlink: $pretty_target -> $pretty_src (backed up real $kind -> $(_prettify "$backup"))"
    _inc LINK_BACKED_UP
    return 0
  fi

  # Target does not exist.
  run_cmd ln -s -- "$src" "$target"
  log "symlink: $pretty_target -> $pretty_src (created)"
  _inc LINK_CREATED
}

# ensure_real_dir <path>
#   Ensures <path> exists and is a real directory (not a symlink).
#   Errors out if <path> is a symlink — callers must back up + remove the
#   symlink first (see link_codex / link_gh for the conversion pattern).
ensure_real_dir() {
  local dir="$1"
  if [ -L "$dir" ]; then
    if (( DRY_RUN == 1 )); then
      # A preceding simulated conversion moved this symlink out of the way.
      run_cmd mkdir -p -- "$dir"
      return 0
    fi
    err "ensure_real_dir: $dir is a symlink; caller must convert it to a real dir first"
  fi
  if [ -d "$dir" ]; then
    return 0
  fi
  if [ -e "$dir" ]; then
    err "ensure_real_dir: $dir exists but is not a directory"
  fi
  run_cmd mkdir -p -- "$dir"
}

# _convert_symlink_dir_to_real <path> [preserved-relative-path...]
#   If <path> is a symlink, back it up (via backup_name) and make room for a
#   real directory. Named ignored paths are moved out of the old symlink target
#   so user-managed state remains at the same home-directory path.
_convert_symlink_dir_to_real() {
  local dir="$1"
  shift
  if [ -L "$dir" ]; then
    local old_dest old_root backup preserve src target
    old_dest="$(readlink -- "$dir" 2>/dev/null || printf '<unreadable>')"
    old_root="$(_canon "$dir")"
    backup="$(backup_name "$dir")"
    log "$(_prettify "$dir") is a symlink -> $old_dest; backing up before converting to real dir"
    run_cmd mv -- "$dir" "$backup"
    run_cmd mkdir -p -- "$dir"
    if (( DRY_RUN == 1 )); then
      DRY_RUN_CONVERTED_DIRS+=("$dir")
    fi
    for preserve in "$@"; do
      src="$old_root/$preserve"
      target="$dir/$preserve"
      if [ -e "$src" ] || [ -L "$src" ]; then
        run_cmd mkdir -p -- "$(dirname "$target")"
        run_cmd mv -- "$src" "$target"
        log "preserved: $(_prettify "$target") moved out of old directory symlink"
      fi
    done
    _inc LINK_BACKED_UP
  fi
}

# --- Link category functions ----------------------------------------------

link_home_dotfiles() {
  local f
  for f in "${HOME_DOTFILES[@]}"; do
    local src="$DOTFILES_DIR/$f"
    if [ ! -e "$src" ]; then
      warn "home dotfile missing in repo, skipping: $f"
      continue
    fi
    link_one "$src" "$HOME/$f"
  done
}

link_codex() {
  local repo_codex="$DOTFILES_DIR/.codex"
  local home_codex="$HOME/.codex"
  if [ ! -d "$repo_codex" ]; then
    warn ".codex/ missing in repo, skipping codex links"
    return 0
  fi

  # If ~/.codex itself is a whole-dir symlink (older layout), back it up so we
  # can lay down a real directory with per-entry symlinks.
  _convert_symlink_dir_to_real "$home_codex" "skills/.system"
  ensure_real_dir "$home_codex"

  # Link every top-level entry under repo/.codex/ except `skills` (handled
  # specially below so we can preserve $HOME/.codex/skills/.system/).
  local entry name
  for entry in "$repo_codex"/* "$repo_codex"/.[!.]*; do
    [ -e "$entry" ] || continue
    name="$(basename -- "$entry")"
    [ "$name" = "skills" ] && continue
    link_one "$entry" "$home_codex/$name"
  done

  # Handle skills/: ensure it's a real directory, then per-entry symlink.
  if [ -d "$repo_codex/skills" ]; then
    local home_skills="$home_codex/skills"
    _convert_symlink_dir_to_real "$home_skills" ".system"
    ensure_real_dir "$home_skills"
    for entry in "$repo_codex/skills"/* "$repo_codex/skills"/.[!.]*; do
      [ -e "$entry" ] || continue
      name="$(basename -- "$entry")"
      [ "$name" = ".system" ] && continue
      link_one "$entry" "$home_skills/$name"
    done
  fi
}

link_gh() {
  local repo_gh="$DOTFILES_DIR/gh"
  local home_gh="$HOME/.config/gh"
  if [ ! -d "$repo_gh" ]; then
    warn "gh/ missing in repo, skipping gh links"
    return 0
  fi

  # ~/.config/gh/ may be a whole-dir symlink from an older install — convert
  # it so hosts.yml (gitignored, holds auth tokens) has a home.
  _convert_symlink_dir_to_real "$home_gh" "hosts.yml"
  ensure_real_dir "$home_gh"

  local entry name
  for entry in "$repo_gh"/* "$repo_gh"/.[!.]*; do
    [ -e "$entry" ] || continue
    name="$(basename -- "$entry")"
    [ "$name" = "hosts.yml" ] && continue
    link_one "$entry" "$home_gh/$name"
  done
}

link_ghostty() {
  local src="$DOTFILES_DIR/ghostty"
  [ -d "$src" ] || { warn "ghostty/ missing in repo, skipping"; return 0; }
  link_one "$src" "$HOME/.config/ghostty"
}

link_nvim() {
  local src="$DOTFILES_DIR/nvim"
  [ -d "$src" ] || { warn "nvim/ missing in repo, skipping"; return 0; }
  link_one "$src" "$HOME/.config/nvim"
}

link_all() {
  log "Linking dotfiles (run timestamp: $RUN_TS)"
  ensure_dir "$HOME/.config"
  link_home_dotfiles
  link_codex
  link_gh
  link_ghostty
  link_nvim
}

# Called by install.sh at the end to give the user a one-line digest.
print_link_summary() {
  log "link summary: created=$LINK_CREATED, already-linked=$LINK_OK, replaced=$LINK_REPLACED, backed-up=$LINK_BACKED_UP"
}
