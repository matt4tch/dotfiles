## Summary
- Add `install.sh` that symlinks every dotfile into place with timestamped
  backups of anything it displaces, and bootstraps missing deps
  (Homebrew/apt/dnf/pacman, Oh My Zsh, p10k, fzf, ripgrep, neovim, nvm, tmux,
  tpm + plugins, sesh).
- Add a Docker-based test harness under `test/` covering Ubuntu 24.04,
  Fedora 41, and Arch Linux.
- Update `README.md` with install + test instructions.

## Motivation
- New machines took ~an hour of manual setup; this is now one command.
- Guarantees `.codex/skills/.system/` and `~/.config/gh/hosts.yml` are preserved
  across reinstalls.

## Design highlights
- **Hand-rolled symlinks** (not `stow`): keeps the flat repo layout, carves
  cleanly around gitignored siblings, no extra bootstrap dependency.
- **Per-file symlinks** for `.codex/` and `gh/` (because `skills/.system/` and
  `hosts.yml` must survive); whole-dir symlinks for `ghostty/` and `nvim/`.
- **One run-level timestamp** for all backups so they're easy to find and
  reruns don't create new ones.
- **Non-interactive end-to-end** — runs clean inside `docker build`.

## Test plan
- [ ] `./install.sh` runs clean on macOS (local).
- [ ] `./install.sh` rerun produces no new backup files (idempotent).
- [ ] `./test/run-tests.sh` passes on Ubuntu, Fedora, and Arch (Docker running).
- [ ] `~/.codex/skills/.system/` content survives a reinstall.
- [ ] `~/.config/gh/hosts.yml` survives a reinstall.
