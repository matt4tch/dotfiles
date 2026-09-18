{
  description = "Portable declarative macOS and Home Manager configuration";

  inputs = {
    # Specify the source of Home Manager and Nixpkgs.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    codex-cli-nix.url = "github:sadjow/codex-cli-nix";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-darwin,
      nix-homebrew,
      codex-cli-nix,
      ...
    }:
    let
      host = import ./nix/hosts/current.nix;
      inherit (host) homeDirectory system username;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      mkDarwin = darwinConfiguration: extraModules: nix-darwin.lib.darwinSystem {
        specialArgs = { inherit homeDirectory system username; };
        modules = [
          nix-homebrew.darwinModules.nix-homebrew
          ./nix/home-manager/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "before-home-manager";
            home-manager.extraSpecialArgs = { inherit codex-cli-nix darwinConfiguration homeDirectory username; };
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
          inherit codex-cli-nix homeDirectory username;
          darwinConfiguration = "macos";
        };
      };
    };
}
