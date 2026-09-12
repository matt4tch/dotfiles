{
  homeDirectory,
  pkgs,
  system,
  username,
  ...
}:

{
  nixpkgs.hostPlatform = system;
  nixpkgs.config.allowUnfree = true;

  # This is the first nix-darwin generation for this machine. Do not change
  # the value later without reviewing the corresponding release notes.
  system.stateVersion = 7;
  system.primaryUser = username;

  users.users.${username}.home = homeDirectory;

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # Pin and install Homebrew itself through Nix. nix-darwin's homebrew module
  # below owns the package inventory; nix-homebrew owns the installation used
  # to realize that inventory and can adopt an existing /opt/homebrew tree.
  nix-homebrew = {
    enable = true;
    user = username;
    autoMigrate = true;
    mutableTaps = false;
  };

  # Preserve the explicit, user-visible preferences on this Mac. Settings that
  # were absent from the defaults database remain unmanaged so macOS can retain
  # its platform defaults.
  system.defaults = {
    NSGlobalDomain = {
      AppleKeyboardUIMode = 0;
      ApplePressAndHoldEnabled = false;
      InitialKeyRepeat = 15;
      KeyRepeat = 2;
      NSAutomaticCapitalizationEnabled = true;
      NSAutomaticPeriodSubstitutionEnabled = true;
    };

    dock = {
      autohide = true;
      mineffect = "genie";
      tilesize = 47;
    };

    finder = {
      FXPreferredViewStyle = "Nlsv";
      ShowExternalHardDrivesOnDesktop = true;
      ShowHardDrivesOnDesktop = false;
      ShowRemovableMediaOnDesktop = true;
    };

    menuExtraClock = {
      ShowAMPM = true;
      ShowDate = 0;
      ShowDayOfWeek = true;
    };

    screencapture.target = "file";

    trackpad = {
      ActuateDetents = true;
      Clicking = false;
      Dragging = false;
      DragLock = false;
      FirstClickThreshold = 1;
      ForceSuppressed = false;
      SecondClickThreshold = 1;
      TrackpadCornerSecondaryClick = 0;
      TrackpadRightClick = true;
      TrackpadThreeFingerDrag = false;
      TrackpadThreeFingerTapGesture = 0;
    };

    WindowManager = {
      AppWindowGroupingBehavior = true;
      AutoHide = false;
      EnableTiledWindowMargins = false;
      HideDesktop = true;
    };
  };

  # These signed application bundles remain Homebrew casks, but Homebrew itself
  # and their desired state are owned by this Nix configuration. Cleanup stays non-destructive:
  # Homebrew 6 also reports removable caches during `brew bundle cleanup`,
  # which makes nix-darwin's check mode reject an otherwise matching package
  # inventory.
  homebrew = {
    enable = true;
    user = username;
    casks = [
      "android-studio"
      "capcut"
      "chatgpt"
      "codex"
      "discord"
      "ghostty"
      "google-chrome"
      "obs"
      "postman"
      "protonvpn"
      "raycast"
      "spotify"
      "surfshark"
      "tor-browser"
      "zoom"
    ];
    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };

  # Manage App Store applications separately from Homebrew Bundle. App IDs are
  # global; account ownership, storefront availability, and sign-in state are
  # machine-local. The native module skips a signed-out account and treats an
  # unavailable individual app as non-fatal, so those differences do not break
  # the rest of the nix-darwin activation.
  programs.mas = {
    enable = true;
    user = username;
    update = false;
    cleanup = false;
    packages = {
      "AdGuard for Safari" = 1440147259;
      GarageBand = 682658836;
      Goodnotes = 1444383602;
      Keynote = 409183694;
      "Microsoft Excel" = 462058435;
      "Microsoft OneNote" = 784801555;
      "Microsoft Outlook" = 985367838;
      "Microsoft PowerPoint" = 462062816;
      "Microsoft Word" = 462054704;
      Numbers = 409203825;
      OneDrive = 823766827;
      Pages = 409201541;
      WhatsApp = 310633997;
      Xcode = 497799835;
    };
  };
}
