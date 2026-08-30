{ lib, pkgs, ... }:

let
  chromeUpdatePolicy = pkgs.writeText "com.google.Keystone.plist" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>updatePolicies</key>
      <dict>
        <key>com.google.Chrome</key>
        <dict>
          <key>UpdateDefault</key>
          <integer>3</integer>
        </dict>
      </dict>
    </dict>
    </plist>
  '';
in

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
    ghostty-bin
    google-chrome
  ];

  # Codex is updated through this flake, so suppress its independent startup
  # update check without taking ownership of the user's mutable config.toml.
  environment.etc."codex/requirements.toml".text = ''
    check_for_update_on_startup = false
  '';

  # Google documents UpdateDefault = 3 as disabling both automatic and
  # user-initiated Chrome application updates. Browser component updates are
  # intentionally left enabled because Nix does not package that mutable data.
  system.activationScripts.postActivation.text = ''
    ${pkgs.coreutils}/bin/install -d -m 0755 '/Library/Managed Preferences'
    ${pkgs.coreutils}/bin/install -m 0644 ${chromeUpdatePolicy} \
      '/Library/Managed Preferences/com.google.Keystone.plist'
  '';

  programs.zsh.enable = true;

  security.pam.services.sudo_local = {
    enable = true;
    touchIdAuth = true;
  };

  # Authenticate once per parent shell, then retain that credential until the
  # shell exits. Run `sudo -k` to revoke it early.
  security.sudo.extraConfig = ''
    Defaults timestamp_type=ppid
    Defaults timestamp_timeout=-1
  '';

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
