{ pkgs, ... }:

{
  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config.allowUnfree = true;

  # This is the first nix-darwin generation for this machine. Do not change
  # the value later without reviewing the corresponding release notes.
  system.stateVersion = 7;
  system.primaryUser = "matthew4.tch";

  users.users."matthew4.tch".home = "/Users/matthew4.tch";

  nix = {
    package = pkgs.nix;
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  # These signed application bundles remain Homebrew casks, but their desired
  # state is owned by this Nix configuration. Cleanup stays non-destructive:
  # Homebrew 6 also reports removable caches during `brew bundle cleanup`,
  # which makes nix-darwin's check mode reject an otherwise matching package
  # inventory.
  homebrew = {
    enable = true;
    user = "matthew4.tch";
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
