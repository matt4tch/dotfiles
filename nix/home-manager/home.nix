{ config, pkgs, ... }:

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
    rustc
    rustfmt
    tree-sitter
    unison
    watchman
    wget
    yarn

    # Lightweight document authoring tools. Quarto and qutebrowser stay on
    # their existing installs for now because their Nix closures are a much
    # larger, separately testable migration batch.
    python312
    sioyek
    typst

    # Keep shell highlighting available without a Homebrew-specific source
    # path. Full shell ownership will move to Home Manager in a later phase.
    zsh-syntax-highlighting
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
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

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
