{ pkgs, ... }:

{
  home.username = "idobbins";
  home.homeDirectory = "/Users/idobbins";

  home.packages = with pkgs; [
    codex
  ];

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.init.defaultBranch = "main";
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

  # Do not change after the first successful activation without reviewing the
  # Home Manager release notes. This is a compatibility marker.
  home.stateVersion = "26.05";
}
