# dotfiles — personal shell / editor / tmux configuration

macOS dependencies are declared with Nix, Home Manager, and nix-darwin.
The shell-based installer remains available for Linux and for linking the
checked-in configuration files on macOS.

## What's in here

Home-directory files (symlinked into `$HOME`):

- `.bash_profile`, `.bashrc`, `.profile`, `.zlogin`, `.zshrc` — shell startup
- `.gitconfig` — git user + aliases
- `.p10k.zsh` — Powerlevel10k prompt
- `.tmux.conf` — tmux config (Nix-managed Dracula, Sensible, Resurrect, Continuum, and Thumbs)
- `.vimrc` — minimal vim fallback
- `.codex/` — Codex CLI config and skills (per-file linked; see Preserved paths)
- `nix/home-manager/` — pinned macOS system, Home Manager, and signed-cask configuration

XDG config (symlinked under `$HOME/.config/`):

- `gh/` — GitHub CLI config (per-file linked; see Preserved paths)
- `ghostty/` — Ghostty terminal config
- `nvim/` — Neovim config (LazyVim-based)

## Install on macOS

### Prereqs

- Nix with flakes enabled
- Homebrew, used only for the six signed/prebuilt casks declared in `darwin.nix`
- `git`

### First activation

```bash
git clone git@github.com:matt4tch/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh --skip-deps
cd nix/home-manager
nix build '.#darwinConfigurations."Matthews-MacBook-Pro".system'
sudo nix run github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
  switch --flake .#Matthews-MacBook-Pro
```

The first system activation installs `darwin-rebuild`. Later rebuilds use the
pinned input directly:

```bash
sudo darwin-rebuild switch --flake .#Matthews-MacBook-Pro
```

The six Homebrew casks are Codex, Discord, Ghostty, ProtonVPN, qutebrowser,
and Raycast. All formulae, shell tools, runtimes, fonts, and plugins are owned
by Home Manager. The cask cleanup policy is deliberately non-destructive.

The standalone Home Manager output can be built without administrator access:

```bash
nix build '.#homeConfigurations."matthew4.tch".activationPackage'
```

## Install on Linux

### Prereqs

- `git` and `curl`
- Passwordless `sudo` for dependency installation

### Run

```bash
git clone git@github.com:matt4tch/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

The Linux installer selects `apt`, `dnf`, or `pacman`, installs the tools used
by the configuration, and safely links each dotfile into place.

### Supported platforms

- macOS on Apple Silicon through the Nix flake
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
# Run the fast cross-platform symlink regression tests.
./test/test-symlinks.sh

# Build and test all three distros.
./test/run-tests.sh

# Build and test a single distro.
./test/run-tests.sh ubuntu
```

The harness also runs `install.sh` twice in each container to confirm
idempotency, and writes dummy `~/.codex/skills/.system/` and
`~/.config/gh/hosts.yml` contents between runs to confirm the second run
leaves them untouched.

macOS can't be tested inside Docker. Validate it by building both flake outputs
shown above before running `darwin-rebuild switch`.

## Troubleshooting

- **`sudo` password prompt on Linux** — the installer assumes passwordless
  sudo. Enable it for your user, or run the script as root.
- **"Docker daemon not running"** — start Docker Desktop, then retry
  `./test/run-tests.sh`.
- **`nvim` complains about Lua version** — the Neovim config needs 0.9.5+.
  Ubuntu 24.04 ships a recent-enough nvim; older Ubuntus do not and are not
  supported.
- **tmux plugins not loading on Linux** — open tmux and press `prefix + I` to
  have tpm install them, or rerun `./install.sh`.
