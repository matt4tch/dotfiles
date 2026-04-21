# dotfiles — personal shell / editor / tmux configuration

One-command bootstrap for a new macOS or Linux machine: symlinks every
config into place and installs the tools the configs reference.

## What's in here

Home-directory files (symlinked into `$HOME`):

- `.bash_profile`, `.bashrc`, `.profile`, `.zlogin`, `.zshrc` — shell startup
- `.gitconfig` — git user + aliases
- `.p10k.zsh` — Powerlevel10k prompt
- `.tmux.conf` — tmux config (uses tpm + dracula, sensible, resurrect, continuum, thumbs)
- `.vimrc` — minimal vim fallback
- `.codex/` — Codex CLI config and skills (per-file linked; see Preserved paths)

XDG config (symlinked under `$HOME/.config/`):

- `gh/` — GitHub CLI config (per-file linked; see Preserved paths)
- `ghostty/` — Ghostty terminal config
- `nvim/` — Neovim config (LazyVim-based)

## Install

### Prereqs

- `git` and `curl`
- On Linux: passwordless `sudo` (the installer uses it to install packages)

### Run

```bash
git clone git@personal-github:matt4tch/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./install.sh
```

### What it does

1. Detects the OS and picks a package manager (Homebrew on macOS; `apt`,
   `dnf`, or `pacman` on Linux).
2. Installs missing dependencies: git, curl, zsh, tmux, fzf, ripgrep,
   neovim, nvm, sesh, Oh My Zsh, Powerlevel10k, tpm, and the tmux plugins
   referenced by `.tmux.conf`.
3. Symlinks every dotfile into place. If a real file or a wrong symlink is
   already at the target, it's moved aside to `<path>.backup-YYYYMMDD-HHMMSS`
   (one timestamp per run) before the new symlink is created.

### Supported platforms

- macOS (Apple Silicon or Intel)
- Ubuntu / Debian
- Fedora
- Arch Linux

### Flags

| Flag | Effect |
|---|---|
| `--dry-run` | Print every action without touching the filesystem. |
| `--skip-deps` | Skip the dependency bootstrap; only manage symlinks. |
| `--skip-links` | Skip the symlinks; only bootstrap dependencies. |
| `--change-shell` | On Linux, change the login shell to zsh via `chsh`. Off by default. |
| `-h`, `--help` | Print usage and exit. |

### Idempotency

Safe to rerun. A second `./install.sh` in a row does nothing: every symlink
is already pointing at the right place, every dep is already installed, and
no new `.backup-*` files are produced.

### Preserved paths

These paths contain user state that must never be clobbered. The installer
works around them:

- `~/.codex/skills/.system/` — system-managed Codex files.
- `~/.config/gh/hosts.yml` — `gh` auth tokens.

Both are gitignored inside the repo and are skipped by the per-file
symlink logic, so reinstalling does not touch them.

## Testing

The Docker-based harness builds one clean image per supported Linux distro
(Ubuntu 24.04, Fedora 41, Arch latest), runs `install.sh` inside each as a
non-root user, and verifies the resulting filesystem.

Requires **Docker Desktop running**.

```bash
# Build and test all three distros.
./test/run-tests.sh

# Build and test a single distro.
./test/run-tests.sh ubuntu
```

The harness also runs `install.sh` twice in each container to confirm
idempotency, and writes dummy `~/.codex/skills/.system/` and
`~/.config/gh/hosts.yml` contents between runs to confirm the second run
leaves them untouched.

macOS can't be tested inside Docker — verify there by running `./install.sh`
on a local macOS host.

## Troubleshooting

- **`sudo` password prompt on Linux** — the installer assumes passwordless
  sudo. Enable it for your user, or run the script as root.
- **"Docker daemon not running"** — start Docker Desktop, then retry
  `./test/run-tests.sh`.
- **`nvim` complains about Lua version** — the Neovim config needs 0.9.5+.
  Ubuntu 24.04 ships a recent-enough nvim; older Ubuntus do not and are not
  supported.
- **tmux plugins not loading** — open tmux and press `prefix + I` to have
  tpm install them, or rerun `./install.sh` (which invokes tpm's installer).
