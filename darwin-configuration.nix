{ inputs, lib, pkgs, ... }:

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

  # Nix remains the primary package manager. Homebrew exists only as a
  # compatibility backend for software that is unavailable through Nix.
  nix-homebrew = {
    enable = true;
    user = "idobbins";
    enableRosetta = false;
    mutableTaps = true;
  };

  # Keep Homebrew limited to macOS apps that Nix cannot install directly.
  # Mullvad's nixpkgs package is explicitly unsupported on Darwin; its cask
  # installs the signed GUI together with the required privileged components.
  homebrew = {
    enable = true;
    casks = [
      "cleanshot"
      "mullvad-vpn"
    ];
    # Install the purchased App Store build so its license stays associated
    # with the signed-in Apple Account.
    masApps.Magnet = 441258766;
    # CleanShot's updater respects the update period attached to its license;
    # do not let Homebrew force-install a newer, potentially unlicensed build.
    global.autoUpdate = false;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "uninstall";
      extraEnv.HOMEBREW_NO_ANALYTICS = "1";
    };
  };
  environment.variables.HOMEBREW_NO_ANALYTICS = "1";

  # Install the CLI at /usr/local/bin/op, the location required by the
  # 1Password desktop application's biometric CLI integration.
  programs._1password.enable = true;

  # The app bundle is immutable in the Nix store, so let Nix own its updates
  # instead of having Sparkle check hourly for an update it cannot install.
  system.defaults.CustomUserPreferences."com.ampcode.amp.macos" = {
    SUEnableAutomaticChecks = false;
    SUAutomaticallyUpdate = false;
  };

  # Fast-moving developer tools track the separately pinned unstable channel.
  # Amp releases faster than even unstable Nixpkgs, so keep its packaging
  # recipe from unstable while pinning the exact upstream macOS ARM release.
  nixpkgs.overlays = [
    (_final: prev:
      let
        unstablePkgs = import inputs.nixpkgs-unstable {
          system = prev.stdenv.hostPlatform.system;
          config.allowUnfreePredicate = pkg:
            builtins.elem (lib.getName pkg) [
              "amp-cli"
              "claude-code"
            ];
        };
      in
      {
        amp-cli = unstablePkgs.amp-cli.overrideAttrs (_old: rec {
          version = "0.0.1788062443-gbd1430";
          src = prev.fetchurl {
            url = "https://static.ampcode.com/cli/${version}/amp-darwin-arm64.gz";
            hash = "sha256-XC7XrpGJDtF16SMcXueV3vriU64eSNG9VvMbW/+BTDc=";
          };
        });
        claude-code = unstablePkgs.claude-code;
        codex = unstablePkgs.codex;
        ampcode = prev.stdenvNoCC.mkDerivation {
          pname = "ampcode";
          version = "1.0.176";

          src = prev.fetchurl {
            name = "amp.dmg";
            # Pin the Google Cloud Storage object generation because
            # latest.dmg is replaced in place for every app release.
            url = "https://static.ampcode.com/mac/latest.dmg?generation=1788178819144821";
            hash = "sha256-PnGSDvGDtscBDyZcmgBF9TDyK4aN80qk/+26orqmkT8=";
          };

          sourceRoot = ".";
          nativeBuildInputs = [ prev._7zz ];

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/Applications"
            cp -a Amp.app "$out/Applications/"
            runHook postInstall
          '';

          meta = {
            description = "Native macOS app for the Amp coding agent";
            homepage = "https://ampcode.com/app";
            license = lib.licenses.unfree;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = lib.platforms.darwin;
          };
        };
        delta-app = prev.stdenvNoCC.mkDerivation {
          pname = "delta-app";
          version = "0.1.0";

          # Delta releases are restricted to authenticated early-access users,
          # so seed this exact archive into the Nix store rather than placing
          # account credentials or an expiring download URL in the flake.
          src = prev.requireFile {
            name = "Delta.app.zip";
            hash = "sha256-8nAzTO+jXyakvPdSvWqnZ9SNkYU9UcNI0byCgsD35Mc=";
            url = "https://delta.dev/download";
          };

          sourceRoot = ".";
          nativeBuildInputs = [ prev.unzip ];

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/Applications"
            cp -a Delta.app "$out/Applications/"
            runHook postInstall
          '';

          meta = {
            description = "Collaborative agent workspace from Zed Industries";
            homepage = "https://delta.dev";
            license = lib.licenses.unfree;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = [ "aarch64-darwin" ];
          };
        };
        t3code-nightly = prev.stdenvNoCC.mkDerivation rec {
          pname = "t3code-nightly";
          version = "0.0.38-nightly.20260901.1246";

          src = prev.fetchurl {
            name = "T3-Code-${version}-arm64.dmg";
            url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-arm64.dmg";
            hash = "sha256-ViHQAqD6YGsXQ7tb09pNicZrSbgd3eYjCcSRHrp0kt8=";
          };

          sourceRoot = ".";
          nativeBuildInputs = [ prev._7zz ];

          # Ignore HFS+ alternate streams: extracting them as colon-suffixed
          # files would invalidate the app's code signature.
          unpackPhase = ''
            runHook preUnpack
            7zz x -sns- "$src"
            runHook postUnpack
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/Applications"
            cp -a ./*/"T3 Code (Nightly).app" "$out/Applications/"
            runHook postInstall
          '';

          meta = {
            description = "Nightly macOS app for T3 Code";
            homepage = "https://t3.codes";
            license = lib.licenses.mit;
            sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
            platforms = [ "aarch64-darwin" ];
          };
        };
        pi-coding-agent = unstablePkgs.pi-coding-agent;
        zed-editor = unstablePkgs.zed-editor;
      })
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password"
      "1password-cli"
      "amp-cli"
      "ampcode"
      "claude-code"
      "delta-app"
      "google-chrome"
      "jetbrains-toolbox"
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
    ampcode
    brave
    delta-app
    ghostty-bin
    google-chrome
    jetbrains-toolbox
    qbittorrent
    t3code-nightly
    zed-editor
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
