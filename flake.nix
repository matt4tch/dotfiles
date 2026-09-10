{
  description = "Declarative macOS and Home Manager configuration for matthew4.tch";

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
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      host = {
        name = "Matthews-MacBook-Pro";
        system = "aarch64-darwin";
        username = "matthew4.tch";
        homeDirectory = "/Users/matthew4.tch";
      };
      inherit (host) homeDirectory system username;
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      darwinConfigurations.${host.name} = nix-darwin.lib.darwinSystem {
        specialArgs = { inherit homeDirectory system username; };
        modules = [
          ./nix/home-manager/darwin.nix
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "before-home-manager";
            home-manager.extraSpecialArgs = { inherit homeDirectory username; };
            home-manager.users.${username} = import ./nix/home-manager/home.nix;
          }
        ];
      };

      # Keep a standalone Home Manager output for building and testing user
      # configuration without requiring administrator privileges.
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [ ./nix/home-manager/home.nix ];
        extraSpecialArgs = { inherit homeDirectory username; };
      };
    };
}
