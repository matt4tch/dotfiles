{
  config,
  homeDirectory,
  lib,
  pkgs,
  username,
  ...
}:

let
  calendarHelperSkill = ../../.codex/skills/apple-calendar-eventkit;
  codexHome = "${config.home.homeDirectory}/.codex";
  codexHookScript = "${codexHome}/hooks/typst_indexed_spacing.py";
  codexHook = action: timeout: {
    hooks = [
      {
        type = "command";
        command = "${pkgs.python3}/bin/python3 ${lib.escapeShellArg codexHookScript} ${action}";
        inherit timeout;
      }
    ];
  };

  # This is copied only when Codex has no user config. Codex owns and mutates
  # the resulting regular file; declarative hook inputs remain separate below.
  codexConfigSeed = (pkgs.formats.toml { }).generate "codex-config.toml" {
    model = "gpt-5.6-sol";
    model_reasoning_effort = "medium";
    approvals_reviewer = "auto_review";
    notify = [
      "${codexHome}/computer-use/Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient"
      "turn-ended"
    ];

    features = {
      memories = true;
      js_repl = false;
    };
    notice.model_migrations."gpt-5.3-codex" = "gpt-5.4";
    tui = {
      vim_mode_default = true;
      model_availability_nux.gpt-6-astra = 4;
    };
    desktop = {
      followUpQueueMode = "queue";
      appearanceTheme = "dark";
      conversationDetailMode = "STEPS_COMMANDS";
    };

    projects = {
      "${config.home.homeDirectory}".trust_level = "untrusted";
      "${config.home.homeDirectory}/dev".trust_level = "trusted";
      "${config.home.homeDirectory}/dotfiles".trust_level = "trusted";
      "${config.home.homeDirectory}/scratch".trust_level = "trusted";
      "${config.home.homeDirectory}/uw".trust_level = "trusted";
      "${config.home.homeDirectory}/uw/f26".trust_level = "trusted";
    };

    marketplaces = {
      openai-bundled = {
        source_type = "local";
        source = "${codexHome}/.tmp/bundled-marketplaces/openai-bundled";
      };
      openai-primary-runtime = {
        source_type = "local";
        source = "${config.home.homeDirectory}/.cache/codex-runtimes/codex-primary-runtime/plugins/openai-primary-runtime";
      };
    };

    plugins = {
      "sites@openai-bundled".enabled = true;
      "visualize@openai-bundled".enabled = true;
      "documents@openai-primary-runtime".enabled = true;
      "pdf@openai-primary-runtime".enabled = true;
      "spreadsheets@openai-primary-runtime".enabled = true;
      "presentations@openai-primary-runtime".enabled = true;
      "template-creator@openai-primary-runtime".enabled = true;
      "browser@openai-bundled".enabled = true;
      "codex-app-tools@openai-bundled".enabled = true;
      "unified-computer-use@openai-bundled".enabled = true;
      "computer-use@openai-bundled".enabled = true;
    };

    mcp_servers = {
      node_repl = {
        args = [ ];
        command = "/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node_repl";
        startup_timeout_sec = 120;
        env = {
          NODE_REPL_NATIVE_PIPE_CONNECT_TIMEOUT_MS = "1000";
          NODE_REPL_NODE_MODULE_DIRS = "/Applications/ChatGPT.app/Contents/Resources/cua_node/lib/node_modules";
          NODE_REPL_NODE_PATH = "/Applications/ChatGPT.app/Contents/Resources/cua_node/bin/node";
          NODE_REPL_TRUSTED_CODE_PATHS = "${codexHome}:/Applications/ChatGPT.app/Contents/Resources/cua_node/lib/node_modules";
          CODEX_HOME = codexHome;
          BROWSER_USE_AVAILABLE_BACKENDS = "chrome,iab";
          BROWSER_USE_TINYSKY_ENABLED = "1";
          NODE_REPL_INSTRUCTIONS_USE_CASE_BROWSER = "";
          NODE_REPL_INSTRUCTIONS_USE_CASE_CHROME = "";
          NODE_REPL_INSTRUCTIONS_USE_CASE_COMPUTER_USE = "";
          BROWSER_USE_CODEX_APP_BUILD_FLAVOR = "prod";
          BROWSER_USE_CODEX_APP_VERSION = "26.903.61454";
          NODE_REPL_TRUSTED_SERVICES = builtins.toJSON {
            browser = "${codexHome}/plugins/cache/openai-bundled/browser/26.903.61454/scripts/browser-service.mjs";
            sky = "@oai/sky/service";
          };
          SKY_CUA_SERVICE_PATH = "${codexHome}/computer-use/Codex Computer Use.app";
          CODEX_CLI_PATH = "/Applications/ChatGPT.app/Contents/Resources/codex";
        };
      };
      computer-use = {
        command = "./Codex Computer Use.app/Contents/SharedSupport/SkyComputerUseClient.app/Contents/MacOS/SkyComputerUseClient";
        args = [ "mcp" ];
        cwd = ".";
        enabled = false;
      };
    };

    shell_environment_policy.set.NODE_REPL_TRUSTED_BROWSER_CLIENT_SHA256S =
      "9230e2bd8b24b7ac7a0ba6774c64bf0d78ecdabbdd91d0ed627b02a587bae2df";
  };

  qutebrowserDracula = pkgs.fetchFromGitHub {
    owner = "dracula";
    repo = "qutebrowser-dracula-theme";
    rev = "791de19ce6a43f0fa52405eea57cba43b4c05a22";
    hash = "sha256-BXTvYFZnzEDlNEOTaWm4m8MEelVrRsUkNdwYKxaxw/g=";
  };

  # Homebrew disabled its qutebrowser cask after the upstream ad-hoc-signed
  # bundle failed Gatekeeper assessment. Pin that same official release in Nix
  # instead; Nix store paths are not quarantined, so the bundle remains usable
  # without compiling Qt WebEngine locally.
  qutebrowserBin = pkgs.stdenvNoCC.mkDerivation {
    pname = "qutebrowser-bin";
    version = "3.7.0";

    src = pkgs.fetchurl {
      url = "https://github.com/qutebrowser/qutebrowser/releases/download/v3.7.0/qutebrowser-3.7.0-arm64.dmg";
      hash = "sha256-mBcCQb8Sov4d6r/8gSC3DcjgDlVbtxLDh1HESPBJVKM=";
    };

    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.undmg
    ];
    sourceRoot = ".";
    dontFixup = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/Applications" "$out/bin"
      cp -R qutebrowser.app "$out/Applications/"
      makeWrapper \
        "$out/Applications/qutebrowser.app/Contents/MacOS/qutebrowser" \
        "$out/bin/qutebrowser"

      runHook postInstall
    '';

    meta = {
      description = "Keyboard-driven browser with a minimal GUI";
      homepage = "https://qutebrowser.org/";
      license = pkgs.lib.licenses.gpl3Plus;
      mainProgram = "qutebrowser";
      platforms = [ "aarch64-darwin" ];
      sourceProvenance = [ pkgs.lib.sourceTypes.binaryNativeCode ];
    };
  };

  # These packages currently have test-suite-only failures on aarch64-darwin
  # after their build products succeed (a randomized floating-point property
  # test in SciPy and snapshot harness failures in inline-snapshot). Override
  # them in this package set so activation is not gated on unstable self-tests.
  pythonForUserTools = pkgs.python312.override {
    packageOverrides = _pythonFinal: pythonPrev: {
      scipy = pythonPrev.scipy.overridePythonAttrs (_oldAttrs: {
        doCheck = false;
      });
      "inline-snapshot" = pythonPrev."inline-snapshot".overridePythonAttrs (_oldAttrs: {
        doCheck = false;
      });
    };
  };

  pythonWithUserTools = pythonForUserTools.withPackages (
    pythonPackages: with pythonPackages; [
      ipykernel
      jupyter
      jupyter-cache
      jupyter-client
      matplotlib
      pynvim
      pyyaml
      scikit-learn
    ]
  );

  # The checked-in .zshrc remains a standalone fallback for the legacy Linux
  # installer. On macOS, import only its explicitly marked personal aliases and
  # functions; Home Manager generates every framework and integration line.
  zshCustomConfig =
    "# Navigation aliases"
    + lib.last (lib.splitString "# Navigation aliases" (builtins.readFile ../../.zshrc));

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
  home.username = username;
  home.homeDirectory = homeDirectory;

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
    gh
    neovim
    nodejs
    ripgrep
    sesh

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

    # Document authoring and course tools. The Python environment replaces the
    # previously user-installed Jupyter, scientific Python, and Neovim provider
    # packages.
    mermaid-cli
    pythonWithUserTools
    quarto
    qutebrowserBin
    racket
    sioyekWithDarwinResources
    texliveMedium
    typst

    # Native macOS fonts and runtimes. Signed GUI applications that cannot be
    # safely repackaged are declared as casks in darwin.nix instead.
    nerd-fonts.hack
    zulu17

  ] ++ [
    # The nix-darwin Home Manager module enables submodule support, under
    # which programs.home-manager does not add its CLI package automatically.
    config.programs.home-manager.package
  ];

  # Files without a useful native Home Manager module are still declarative:
  # activation links these version-controlled sources from the Nix store.
  home.file = {
    "Library/Application Support/sioyek/keys_user.config".source = ./sioyek/keys_user.config;
    ".bash_profile".source = ../../.bash_profile;
    ".bashrc".source = ../../.bashrc;
    ".profile".source = ../../.profile;
    ".p10k.zsh".source = ../../.p10k.zsh;
    ".vimrc".source = ../../.vimrc;
    ".qutebrowser/config.py".text = ''
      import dracula.draw

      # Load settings changed interactively with :set from autoconfig.yml.
      config.load_autoconfig()

      dracula.draw.blood(c, {
          "spacing": {
              "vertical": 6,
              "horizontal": 8,
          }
      })
    '';
    ".qutebrowser/dracula".source = qutebrowserDracula;

    # tmux itself writes the generated configuration under XDG_CONFIG_HOME.
    # Keep the traditional path as a managed link because tmux prefers it when
    # both locations exist.
    ".tmux.conf".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/tmux/tmux.conf";

    # Preserve Codex's runtime-managed config and skills/.system directory by
    # managing only immutable, declarative inputs around them.
    ".codex/AGENTS.md".source = ../../.codex/AGENTS.md;
    ".codex/hooks.json".text = builtins.toJSON {
      hooks = {
        SessionStart = [ (codexHook "start" 30) ];
        Stop = [ (codexHook "stop" 30) ];
        SessionEnd = [ (codexHook "end" 3) ];
      };
    };
    ".codex/hooks".source = ../../.codex/hooks;
    ".codex/skills/apple-calendar-eventkit".source = calendarHelperSkill;
    ".codex/skills/git-usage".source = ../../.codex/skills/git-usage;

    # Generate the conventional Git path too. This prevents an older
    # ~/.gitconfig from shadowing Home Manager's XDG Git configuration.
    ".gitconfig".text = lib.generators.toGitINI {
      user = {
        name = "Matthew Tchouikine";
        email = "matthew4.tch@gmail.com";
      };
      init.defaultBranch = "main";
    };
  };

  home.activation.ensureWritableCodexConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    codex_config=${lib.escapeShellArg "${codexHome}/config.toml"}

    if [[ -L "$codex_config" ]]; then
      codex_config_target="$(readlink "$codex_config")"
      case "$codex_config_target" in
        /nix/store/*)
          $DRY_RUN_CMD /bin/rm -f "$codex_config"
          ;;
        *)
          echo "Refusing to replace unmanaged Codex config link: $codex_config -> $codex_config_target" >&2
          exit 1
          ;;
      esac
    fi

    if [[ ! -e "$codex_config" ]]; then
      $DRY_RUN_CMD /bin/mkdir -p ${lib.escapeShellArg codexHome}
      $DRY_RUN_CMD /usr/bin/install -m 0600 ${codexConfigSeed} "$codex_config"
    fi
  '';

  home.sessionVariables = {
    VISUAL = "nvim";
  };

  xdg.configFile = {
    "gh/config.yml".source = ../../gh/config.yml;
    "ghostty".source = ../../ghostty;
    "nvim".source = ../../nvim;
  };

  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Matthew Tchouikine";
        email = "matthew4.tch@gmail.com";
      };
      init.defaultBranch = "main";
    };
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "rg --files";
    defaultOptions = [
      "-m"
      "--color=fg:#f8f8f2,bg:#282a36,hl:#bd93f9,fg+:#f8f8f2,bg+:#44475a,hl+:#bd93f9,info:#ffb86c,prompt:#50fa7b,pointer:#ff79c6,marker:#ff79c6,spinner:#ffb86c,header:#6272a4"
    ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    dotDir = config.home.homeDirectory;
    defaultKeymap = "viins";
    loginExtra = builtins.readFile ../../.zlogin;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "colored-man-pages"
      ];
      extraConfig = ''
        DEFAULT_USER=$USER
        DISABLE_LS_COLORS="true"
        zstyle ':omz:update' mode disabled
      '';
    };
    initContent = lib.mkMerge [
      (lib.mkOrder 500 ''
        if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]]; then
          source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
        fi
      '')
      (lib.mkOrder 550 ''
        # A terminal app that was already running during a nix-darwin switch
        # can retain the old environment guard and PATH. Resolve the active
        # Home Manager profile on every interactive shell so Nix-managed
        # commands take precedence immediately after activation.
        nix_profile_roots=(
          "/etc/profiles/per-user/$USER"
          "''${XDG_STATE_HOME:-$HOME/.local/state}/home-manager/gcroots/current-home/home-path"
          "$HOME/.nix-profile"
          "''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profiles/profile"
        )
        for nix_profile_root in "''${nix_profile_roots[@]}"; do
          if [[ -d "$nix_profile_root/bin" ]]; then
            path=("$nix_profile_root/bin" "''${(@)path:#$nix_profile_root/bin}")
            break
          fi
        done
        typeset -gU path PATH
        export PATH
        unset nix_profile_root nix_profile_roots
      '')
      (lib.mkOrder 900 ''
        # Source the theme directly instead of registering it as a generic zsh
        # plugin, which would add its source directory to executable PATH.
        source "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme"
      '')
      (lib.mkOrder 1000 ''
        # Preferred editor for local and remote sessions.
        if [[ -n $SSH_CONNECTION ]]; then
          export EDITOR='vim'
        else
          export EDITOR='nvim'
        fi

        # Home Manager loads powerlevel10k before this custom configuration.
        [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

        ${zshCustomConfig}
      '')
    ];
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    keyMode = "vi";
    escapeTime = 0;
    historyLimit = 1000000;
    mouse = true;
    focusEvents = true;
    plugins = with pkgs.tmuxPlugins; [
      sensible
      {
        plugin = dracula;
        extraConfig = ''
          set -g @dracula-show-powerline true
          set -g @dracula-show-left-icon "#S"
          set -g @dracula-transparent-powerline-bg true
          set -g @dracula-show-left-sep 
          set -g @dracula-show-right-sep 
          set -g @dracula-plugins "time"
        '';
      }
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-processes 'codex'
        '';
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'off'
        '';
      }
      tmux-thumbs
    ];
    extraConfig = ''
      ${builtins.readFile ./tmux.conf}

      # Save the current state when the last client detaches. The immutable
      # plugin path is supplied directly by Nix, with no profile probing.
      set-hook -g client-detached 'run-shell "${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/save.sh"'
    '';
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

  # EventKit attributes Calendar permission to the signed application identity.
  # Install the helper on a fresh machine, but preserve a valid existing bundle
  # so routine switches do not change its ad-hoc signature and revoke access.
  home.activation.ensureCalendarHelper = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    helper_app="${config.home.homeDirectory}/Applications/Codex Calendar Helper.app"
    helper_binary="$helper_app/Contents/MacOS/calendar-helper"

    if [[ ! -e "$helper_app" ]]; then
      CODEX_CALENDAR_HELPER_APP="$helper_app" \
        /bin/zsh "${calendarHelperSkill}/scripts/install_helper.sh"
    elif [[ ! -x "$helper_binary" ]]; then
      echo "Calendar helper exists but its executable is missing: $helper_binary" >&2
      exit 1
    elif ! /usr/bin/codesign --verify --strict "$helper_app"; then
      echo "Calendar helper has an invalid code signature: $helper_app" >&2
      exit 1
    elif [[ "$(/usr/bin/plutil -extract CFBundleIdentifier raw "$helper_app/Contents/Info.plist")" != \
      "com.matthew4tch.CodexCalendarHelper" ]]; then
      echo "Calendar helper has an unexpected bundle identifier: $helper_app" >&2
      exit 1
    fi
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
