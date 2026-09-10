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

  # These signed application bundles remain Homebrew casks, but their desired
  # state is owned by this Nix configuration. Cleanup stays non-destructive:
  # Homebrew 6 also reports removable caches during `brew bundle cleanup`,
  # which makes nix-darwin's check mode reject an otherwise matching package
  # inventory.
  homebrew = {
    enable = true;
    user = username;
    casks = [
      "codex"
      "discord"
      "ghostty"
      "protonvpn"
      "qutebrowser"
      "raycast"
    ];
    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
    };
  };
}
