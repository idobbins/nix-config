{
  description = "Isaac's macOS configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0";

    # Keep the system on stable Nixpkgs while allowing fast-moving tools to
    # opt into a separately pinned unstable revision.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "https://flakehub.com/f/nix-darwin/nix-darwin/0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "https://flakehub.com/f/nix-community/home-manager/0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # This module keeps nix-darwin from taking ownership of the Determinate
    # Nix daemon and its vendor-managed /etc/nix/nix.conf.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  outputs = inputs@{ nix-darwin, home-manager, determinate, ... }: {
    darwinConfigurations."Isaacs-MacBook-Pro" = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit inputs; };

      modules = [
        determinate.darwinModules.default
        home-manager.darwinModules.home-manager
        ./darwin-configuration.nix
      ];
    };
  };
}
