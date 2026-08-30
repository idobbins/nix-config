# macOS configuration

This flake manages Isaac's Mac with Determinate Nix, nix-darwin, and Home
Manager.

## Ownership boundaries

- Determinate owns the Nix daemon, store mount, certificates, garbage
  collection, and `/etc/nix/nix.conf`.
- nix-darwin owns system packages and copies managed GUI applications into
  `/Applications/Nix Apps`.
- Home Manager owns user CLI packages and shell configuration.
- Apple owns the Xcode Command Line Tools and macOS SDK. Verify the bootstrap
  dependency with `xcode-select -p` and update it through Software Update.
- Secrets, SSH private keys, 1Password data, Chrome profiles, and Codex state
  remain mutable and outside the Nix store.

## Commands

Build without activating:

```sh
nix build .#darwinConfigurations.Isaacs-MacBook-Pro.system
```

Activate:

```sh
sudo ./result/activate
```

Build as the normal user before elevating. This also avoids asking root to
evaluate a user-owned Git checkout.

Update pinned inputs, review the lock-file diff, build, and then activate:

```sh
nix flake update
git diff -- flake.lock
nix build .#darwinConfigurations.Isaacs-MacBook-Pro.system
sudo ./result/activate
```

The GitHub SSH key is stored at `~/.ssh/id_ed25519_github`; only its `.pub`
file is safe to upload or share.
