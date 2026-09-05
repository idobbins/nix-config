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
    masApps = {
      Magnet = 441258766;
      Xcode = 497799835;
    };
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
              "chatgpt"
              "claude-code"
            ];
        };
      in
      {
        amp-cli = unstablePkgs.amp-cli.overrideAttrs (_old: rec {
          version = "0.0.1788624043-gf294bf";
          src = prev.fetchurl {
            url = "https://static.ampcode.com/cli/${version}/amp-darwin-arm64.gz";
            hash = "sha256-jxXfMkIPExuvsKQosCCA45pYUKTtnlnKQBRWQRpMK2o=";
          };
        });
        chatgpt = unstablePkgs.chatgpt.overrideAttrs (_old: rec {
          version = "26.901.41123";
          src = prev.fetchurl {
            url = "https://persistent.oaistatic.com/codex-app-prod/ChatGPT-darwin-arm64-${version}.zip";
            hash = "sha256-8Nb8q26xxmrE+FhbxbVpJrLYdwDHt8wRRCnntUAZP9Y=";
          };
        });
        claude-code = unstablePkgs.claude-code.override {
          manifest = {
            version = "2.1.261";
            platforms.darwin-arm64 = {
              binary = "claude.zst";
              checksum = "c7960a08d4b6a683618a3e739b8338bffa98429fa7806cb3ae31652003e487d0";
            };
          };
        };
        codex = prev.stdenvNoCC.mkDerivation {
          pname = "codex";
          version = "0.153.4";

          src = prev.fetchurl {
            url = "https://github.com/openai/codex/releases/download/rust-v0.153.4/codex-package-aarch64-apple-darwin.tar.gz";
            hash = "sha256-NUONofv3ptt92zvOyERI+mAVuhiEYUcql9nR2n2cQ1M=";
          };

          sourceRoot = ".";
          dontStrip = true;
          nativeBuildInputs = [ prev.installShellFiles ];

          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            cp -R bin codex-package.json codex-path codex-resources "$out/"
            runHook postInstall
          '';

          postInstall = ''
            installShellCompletion --cmd codex \
              --bash <("$out/bin/codex" completion bash) \
              --fish <("$out/bin/codex" completion fish) \
              --zsh <("$out/bin/codex" completion zsh)
          '';

          meta = unstablePkgs.codex.meta;
        };
        ampcode = prev.stdenvNoCC.mkDerivation {
          pname = "ampcode";
          version = "1.0.265";

          src = prev.fetchurl {
            name = "amp.dmg";
            # Use the immutable, versioned release rather than latest.dmg.
            url = "https://static.ampcode.com/mac/Amp-1.0-265.dmg";
            hash = "sha256-6Y77PPesp5+wO9F2sjTXuykohzheXKSsj+UIhRqDNTQ=";
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
        t3code-nightly = prev.stdenvNoCC.mkDerivation rec {
          pname = "t3code-nightly";
          version = "0.0.39-nightly.20260905.1288";

          src = prev.fetchurl {
            name = "T3-Code-${version}-arm64.dmg";
            url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-${version}-arm64.dmg";
            hash = "sha256-0eqpMpyRSpoigpJhYYcguTwBGuljChbH5pCofkCRLiQ=";
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
        pi-coding-agent = unstablePkgs.pi-coding-agent.overrideAttrs (_old: rec {
          version = "0.85.1";
          src = prev.fetchFromGitHub {
            owner = "earendil-works";
            repo = "pi";
            tag = "v${version}";
            hash = "sha256-gU8BSiqqOYt2RRuQONHHGvZeSM5KFQVrwif9bmuUXUc=";
          };
          # 0.85 adds the chord workspace as a build and runtime dependency.
          buildPhase = builtins.replaceStrings
            [ "npx tsgo -p packages/tui/tsconfig.build.json" ]
            [ "npx tsgo -p packages/chord/tsconfig.build.json\n    npx tsgo -p packages/tui/tsconfig.build.json" ]
            _old.buildPhase;
          postInstall = builtins.replaceStrings
            [ "for ws in @earendil-works/pi-ai:packages/ai" ]
            [ "for ws in @earendil-works/chord:packages/chord @earendil-works/pi-ai:packages/ai" ]
            _old.postInstall;
          npmDeps = _old.npmDeps.overrideAttrs {
            inherit src;
            name = "pi-coding-agent-${version}-npm-deps";
            outputHash = "sha256-jzlsZIQzfl1FCZZ5//dHFWwMfBZQ4nRD6KB4HHifPqE=";
          };
          modelData = prev.fetchurl {
            url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${version}.tgz";
            hash = "sha256-r30RmGF5RFzm/oizfVfeIvgjwP/TplyuMcVVt/XpklM=";
          };
        });
        zed-editor = prev.stdenvNoCC.mkDerivation {
          pname = "zed-editor";
          version = "1.18.1";

          src = prev.fetchurl {
            url = "https://github.com/zed-industries/zed/releases/download/v1.18.1/Zed-aarch64.dmg";
            hash = "sha256-bEiPxp1ThxXLW6KpnUpFiX6ErKGCEaMFSSkcuQ5LZUY=";
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
            mkdir -p "$out/Applications" "$out/bin"
            cp -a Zed.app "$out/Applications/"
            ln -s ../Applications/Zed.app/Contents/MacOS/cli "$out/bin/zeditor"
            runHook postInstall
          '';

          meta = unstablePkgs.zed-editor.meta;
        };
      })
  ];

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "1password"
      "1password-cli"
      "amp-cli"
      "ampcode"
      "chatgpt"
      "claude-code"
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
    chatgpt
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
