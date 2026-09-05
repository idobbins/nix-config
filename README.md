# macOS configuration

This flake manages Isaac's Mac with Determinate Nix, nix-darwin, and Home
Manager.

## Ownership boundaries

- Determinate owns the Nix daemon, store mount, certificates, garbage
  collection, and `/etc/nix/nix.conf`.
- nix-darwin owns system packages and copies managed GUI applications into
  `/Applications/Nix Apps`.
- Home Manager owns all global user CLI packages (including Node.js and
  Vercel), shell configuration, and Neovim. Do not use `nix profile install`
  or `npm install -g` for global tools; declare them in `home.nix` instead.
- Vercel's package recipe and npm lock file live in `packages/vercel-cli/`
  and use this flake's Nixpkgs input, not a separate flake or user profile.
- Project-specific development shells stay in their project repositories.
- Pi extension versions are pinned in `home.nix`; Pi downloads those
  extensions into its runtime cache.
- Neovim plugins, Tree-sitter parsers, and language servers come from the
  pinned Nixpkgs revision; Neovim does not download them at runtime.
- Home Manager registers Ghostty as the default macOS terminal handler for
  Unix executables and enables its Zsh integration.
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

## Neovim

Home Manager installs Neovim, configures Ayu Light, and sets `nvim` as
`EDITOR` and `VISUAL`. Plugins, selected Tree-sitter parsers, FFF's native
library, and language servers are built as part of the system closure. Update
them through the normal flake update and activation workflow rather than
`:Lazy`, `:Mason`, or `:TSUpdate`.

## Sudo authentication

`sudo` uses Touch ID and caches authentication once per parent shell until
that shell exits. Run `sudo -k` to revoke the current shell's cached
credential early.
