{ config, pkgs, ... }:

let
  # Sioyek's August 2026 macOS code resolves its bundled read-only data from
  # Contents/Resources, while the current Nixpkgs derivation installs it under
  # Contents/MacOS. Ensure every path used by configure_paths() exists in the
  # bundle location expected at runtime.
  sioyekWithDarwinResources = pkgs.sioyek.overrideAttrs (oldAttrs: {
    postInstall = (oldAttrs.postInstall or "") + ''
      app_contents="$out/Applications/sioyek.app/Contents"
      mkdir -p "$app_contents/Resources"

      ensure_resource() {
        resource_name="$1"
        source_path="$app_contents/MacOS/$resource_name"
        destination_path="$app_contents/Resources/$resource_name"

        # Prefer an upstream-installed resource when Nixpkgs fixes the bundle.
        if [[ -e "$destination_path" ]]; then
          return
        fi

        if [[ ! -e "$source_path" ]]; then
          echo "Sioyek resource '$resource_name' is missing from both Contents/Resources and Contents/MacOS" >&2
          exit 1
        fi

        cp -R "$source_path" "$destination_path"
      }

      ensure_resource shaders
      ensure_resource prefs.config
      ensure_resource keys.config
      ensure_resource tutorial.pdf
    '';
  });

  tmuxRestoreOnLogin = pkgs.writeShellScript "tmux-restore-on-login" ''
    export PATH="${pkgs.tmux}/bin:/usr/bin:/bin:/usr/sbin:/sbin"

    tmux_bin="${pkgs.tmux}/bin/tmux"
    restore_script="${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/restore.sh"
    bootstrap_session="__tmux_restore__"

    # Preserve a server that is already running (for example, after logging
    # out and back in without a reboot).
    if "$tmux_bin" list-sessions >/dev/null 2>&1; then
      exit 0
    fi

    "$tmux_bin" new-session -d -s "$bootstrap_session" || exit 1

    if [[ -x "$restore_script" ]]; then
      # Resurrect discovers the tmux socket through TMUX. run-shell supplies
      # that context while still waiting synchronously for restoration.
      "$tmux_bin" run-shell -t "$bootstrap_session:0.0" "$restore_script"
    fi

    "$tmux_bin" kill-session -t "=$bootstrap_session" 2>/dev/null
  '';
in

{
  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "matthew4.tch";
  home.homeDirectory = "/Users/matthew4.tch";

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "26.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    # Core interactive toolchain. This is the first migration batch from
    # Homebrew and the imperative installers in lib/deps.sh.
    fd
    fswatch
    fzf
    gh
    git
    neovim
    nodejs
    ripgrep
    sesh
    tmux
    zoxide

    # General command-line utilities previously installed as Homebrew
    # formulae. Library-only build dependencies will instead belong to the
    # project dev shells that need them.
    automake
    autoconf
    bun
    cargo
    clippy
    coreutils-prefixed
    duti
    ffmpeg
    ghostscript
    gnupg
    imagemagick
    jq
    lazygit
    luarocks
    minisat
    opencode
    poppler-utils
    postgresql_16
    pkg-config
    rustc
    rustfmt
    tree-sitter
    unison
    watchman
    wget
    yarn

    # Shell and tmux plugins. The checked-in configuration files source these
    # from the active profile instead of mutable Git checkouts.
    oh-my-zsh
    zsh-powerlevel10k
    tmuxPlugins.continuum
    tmuxPlugins.dracula
    tmuxPlugins.resurrect
    tmuxPlugins.sensible
    tmuxPlugins.tmux-thumbs

    # Document authoring tools. qutebrowser stays on Homebrew for now because
    # its pinned Nix package requires a large local Qt WebEngine build.
    python312
    quarto
    sioyekWithDarwinResources
    typst

    # Native macOS fonts and runtimes. Signed GUI applications that cannot be
    # safely repackaged are declared as casks in darwin.nix instead.
    nerd-fonts.hack
    zulu17

    # Keep shell highlighting available without a Homebrew-specific source
    # path. Full shell ownership will move to Home Manager in a later phase.
    zsh-syntax-highlighting
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    "Library/Application Support/sioyek/keys_user.config".source = ./sioyek/keys_user.config;

    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/matthew4.tch/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # Restore the last tmux-resurrect snapshot at login without relying on the
  # mutable ~/.local/bin helper or a Homebrew tmux installation.
  launchd.agents.tmux-restore = {
    enable = true;
    config = {
      Label = "com.matthew.tmux-restore";
      ProgramArguments = [ "${tmuxRestoreOnLogin}" ];
      RunAtLoad = true;
      ProcessType = "Background";
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/tmux-restore-on-login.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/tmux-restore-on-login.log";
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
