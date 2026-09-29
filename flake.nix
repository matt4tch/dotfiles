{
  description = "Portable declarative macOS and Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # A second, independently locked nixpkgs. Fast-moving packages listed in
    # `freshOverlay` below are taken from here instead of the main pin, so
    # they can be updated without moving every other package. Bump with:
    #   nix flake update nixpkgs-fresh
    nixpkgs-fresh.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-fresh,
      home-manager,
      nix-darwin,
      nix-homebrew,
      ...
    }:
    let
      host = import ./nix/local-context.nix;
      inherit (host) homeDirectory system username;

      # Packages pulled from `nixpkgs-fresh` rather than the main pin. Both of
      # these release far more often than the rest of the closure. Add a name
      # here to track a package's newer version without moving anything else;
      # remove it once the main pin has caught up.
      freshOverlay = final: prev: {
        inherit
          (import nixpkgs-fresh {
            inherit (prev.stdenv.hostPlatform) system;
            inherit (prev) config;
          })
          claude-code
          codex
          ;
      };

      nixpkgsArgs = {
        config.allowUnfree = true;
        overlays = [ freshOverlay ];
      };

      pkgs = import nixpkgs ({ inherit system; } // nixpkgsArgs);
      mkDarwin = darwinConfiguration: extraModules: nix-darwin.lib.darwinSystem {
        specialArgs = { inherit homeDirectory system username; };
        modules = [
          nix-homebrew.darwinModules.nix-homebrew
          { nixpkgs.overlays = [ freshOverlay ]; }
          ./nix/home-manager/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "before-home-manager";
            home-manager.extraSpecialArgs = { inherit darwinConfiguration homeDirectory username; };
            home-manager.users.${username} = import ./nix/home-manager/home.nix;
          }
        ] ++ extraModules;
      };
    in
    {
      darwinConfigurations = {
        macos = mkDarwin "macos" [ ];
        work-mac = mkDarwin "work-mac" [ ./nix/hosts/work-mac.nix ];
      };

      # Keep a standalone Home Manager output for building and testing user
      # configuration without requiring administrator privileges.
      homeConfigurations.default = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ ./nix/home-manager/home.nix ];
        extraSpecialArgs = {
          inherit homeDirectory username;
          darwinConfiguration = "macos";
        };
      };
    };
}
