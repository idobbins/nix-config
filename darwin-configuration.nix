{ lib, pkgs, ... }:

{
  # Determinate continues to own and update Nix itself. nix-darwin manages
  # the rest of the macOS system configuration around it.
  determinateNix.enable = true;

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password"
      "google-chrome"
    ];

  system.primaryUser = "idobbins";

  users.users.idobbins = {
    name = "idobbins";
    home = "/Users/idobbins";
  };

  # nix-darwin copies application bundles from systemPackages into
  # /Applications/Nix Apps so Spotlight and Launch Services can see them.
  environment.systemPackages = with pkgs; [
    _1password-gui
    google-chrome
  ];

  programs.zsh.enable = true;

  # macOS 26 protects this PAM path from replacement even by an elevated
  # graphical process. Leave it under Apple's ownership; we are not enabling
  # Touch ID or Apple Watch authentication for sudo here.
  security.pam.services.sudo_local.enable = false;

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "before-home-manager";
    users.idobbins = import ./home.nix;
  };

  # Do not change after the first successful activation without reviewing the
  # nix-darwin release notes. This is a compatibility marker, not a version pin.
  system.stateVersion = 6;
}
