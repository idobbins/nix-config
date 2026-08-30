{ lib, pkgs, ... }:

{
  home.username = "idobbins";
  home.homeDirectory = "/Users/idobbins";

  home.packages = with pkgs; [
    codex
    duti
  ];

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.init.defaultBranch = "main";
  };

  programs.ghostty = {
    enable = true;
    # The signed macOS application is installed system-wide by nix-darwin.
    package = null;
    enableZshIntegration = true;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings."github.com" = {
      HostName = "github.com";
      User = "git";
      IdentityFile = "~/.ssh/id_ed25519_github";
      IdentitiesOnly = true;
      AddKeysToAgent = "yes";
      UseKeychain = "yes";
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    profileExtra = ''
      # User login-shell initialization is managed by Home Manager.
    '';
  };

  # Ghostty itself defines the macOS default terminal as the handler for
  # public.unix-executable. Re-apply that LaunchServices association whenever
  # Home Manager activates so it remains part of the declarative setup.
  home.activation.setDefaultTerminal = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ghostty_app="/Applications/Nix Apps/Ghostty.app"
    lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

    if [[ ! -d "$ghostty_app" ]]; then
      echo "Ghostty application is missing at $ghostty_app" >&2
      exit 1
    fi

    "$lsregister" -f "$ghostty_app"
    ${pkgs.duti}/bin/duti -s com.mitchellh.ghostty public.unix-executable all
  '';

  # Do not change after the first successful activation without reviewing the
  # Home Manager release notes. This is a compatibility marker.
  home.stateVersion = "26.05";
}
