{ lib, pkgs, ... }:

let
  emptyJson = pkgs.writeText "empty.json" "{}";

  # Pi owns runtime state such as changelog acknowledgements, while these
  # settings are reconciled from Nix on every Home Manager activation.
  managedPiSettings = pkgs.writeText "pi-managed-settings.json" (builtins.toJSON {
    defaultProvider = "openai-codex";
    defaultModel = "gpt-5.6-sol";
    defaultThinkingLevel = "high";
    theme = "light";
    npmCommand = [ "${pkgs.nodejs}/bin/npm" ];
    packages = [
      "npm:pi-web-search@1.3.1"
      "npm:pi-claude-bridge@0.7.0"
    ];
  });

  managedClaudeBridgeSettings = pkgs.writeText "claude-bridge-managed-settings.json" (builtins.toJSON {
    askClaude.enabled = false;
  });
in

{
  imports = [
    ./modules/dev-profiles.nix
    ./profiles/hades.nix
  ];

  home.username = "idobbins";
  home.homeDirectory = "/Users/idobbins";

  home.packages = with pkgs; [
    _1password-cli
    amp-cli
    claude-code
    codex
    duti
    gh
    pi-coding-agent
  ];

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;
    settings.init.defaultBranch = "main";
  };

  programs.ghostty = {
    enable = true;
    # The signed macOS application is installed system-wide by nix-darwin.
    package = null;
    enableZshIntegration = true;
    settings.auto-update = "off";
    settings.macos-titlebar-style = "tabs";
    settings.theme = "Ayu Light";
  };

  # Herdr defaults to its own dark Catppuccin theme. The terminal theme uses
  # Ghostty's active ANSI palette, while explicit Ayu Light surfaces avoid the
  # dark, low-contrast selection colors derived from the ANSI gray slots.
  xdg.configFile."herdr/config.toml".text = ''
    [theme]
    name = "terminal"

    [theme.custom]
    panel_bg = "reset"
    sidebar_bg = "#f8f9fa"
    active_row_bg = "#e8edf2"
    selection_bg = "#dce9f8"
    surface0 = "#f3f4f5"
    surface1 = "#e7e8e9"
    surface_dim = "#d1d1d1"

    [experimental]
    kitty_graphics = true
  '';

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

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    profileExtra = ''
      # User login-shell initialization is managed by Home Manager.
    '';
    initContent = ''
      # Keep package-management subcommands unchanged; agent sessions skip
      # AGENTS.md and CLAUDE.md unless `command pi` is used explicitly.
      pi() {
        case "''${1-}" in
          install|remove|uninstall|update|list|config|auth)
            command pi "$@"
            ;;
          *)
            command pi --no-context-files "$@"
            ;;
        esac
      }
    '';
  };

  # Keep repositories grouped by the identity or organization they belong to.
  # These mutable directories are created during activation rather than linked
  # into the immutable Nix store.
  home.activation.createDevDirectories = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p \
      "$HOME/dev/self" \
      "$HOME/dev/fundlaunch" \
      "$HOME/dev/donkey"
  '';

  home.activation.cloneRepositories = lib.hm.dag.entryAfter [ "createDevDirectories" ] ''
    repo="$HOME/dev/self/realtimerays"

    if [[ ! -d "$repo/.git" ]]; then
      run ${pkgs.git}/bin/git \
        -c core.sshCommand=/usr/bin/ssh \
        clone \
        git@github.com:idobbins/realtimerays.git \
        "$repo"
    fi
  '';

  home.activation.configurePi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    pi_config_dir="$HOME/.pi/agent"
    run mkdir -p "$pi_config_dir"

    merge_pi_json() {
      target="$1"
      managed="$2"
      current=${emptyJson}
      tmp="$target.tmp.$$"

      if [[ -s "$target" ]]; then
        current="$target"
      fi

      ${pkgs.jq}/bin/jq -s '.[0] * .[1]' "$current" "$managed" > "$tmp"
      run chmod 0644 "$tmp"
      run mv "$tmp" "$target"
    }

    merge_pi_json "$pi_config_dir/settings.json" ${managedPiSettings}
    merge_pi_json "$pi_config_dir/claude-bridge.json" ${managedClaudeBridgeSettings}
  '';

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
