# sfd-nix

This flake packages the official sing-box desktop clients:

- [SagerNet/sing-box-for-desktop](https://github.com/SagerNet/sing-box-for-desktop) on Linux
- [SagerNet/sing-box-for-apple](https://github.com/SagerNet/sing-box-for-apple) on macOS

Both packages match sing-box `1.14.0`. The Linux client is pinned to
revision `92b69e160d30249e8fc21a1106df6af538f0fb92`; the Apple client matches
revision `59540eb0e1812bb76a481a9dc3dec6a788f4196f`.

## Run or build

```console
nix build --accept-flake-config .#sing-box-for-desktop
nix run --accept-flake-config .
```

On `x86_64-linux` and `aarch64-linux`, the package uses the upstream-matched
Node.js 26.7, Electron 43.4, and sing-box 1.14.0 toolchain. The following
NixOS module and declarative settings apply only to this Linux package.

The standalone package contains the UI and its matching daemon, but a normal user cannot install the required system service. On NixOS, use the module for a working client:

```nix
{
  inputs.sfd-nix.url = "git+https://forge.asnk.io/sugar/sfd-nix";

  outputs = { nixpkgs, sfd-nix, ... }: {
    nixosConfigurations.my-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        sfd-nix.nixosModules.default
        {
          programs.sing-box-for-desktop.enable = true;
        }
      ];
    };
  };
}
```

This installs the desktop entry and PolicyKit action, enables `pkexec`, and
starts `sing-box-daemon.service`. The daemon socket is
`/run/sing-box-daemon/sing-box.socket`; daemon state is stored in
`/var/lib/sing-box-daemon`.

## macOS

The Darwin output supports Apple Silicon (`aarch64-darwin`) and contains the
official signed and notarized `SFM` standalone client. It deliberately does not
reuse the Linux patches, daemon, declarative settings, NixOS module, or any
nix-darwin/Home Manager integration.

The Apple app cannot be built into a functional client without Apple-issued
Network Extension and System Extension entitlements, provisioning profiles,
Developer ID certificates, and notarization. The derivation therefore extracts
upstream's signed `SFM.app` without modifying its Mach-O files and retains the
original installer package. For a functional system installation, use the
installer rather than relying on an application symlink into the Nix store:

```console
nix build --accept-flake-config .#sing-box-for-apple
sudo /usr/sbin/installer \
  -pkg result/share/sing-box-for-apple/SFM.pkg \
  -target /
```

The extracted app is also available at `result/Applications/SFM.app`. The
installer requires macOS 13 or newer. Intel macOS is not exposed because the
currently pinned nixpkgs revision no longer supports `x86_64-darwin`.

## Declarative settings

Desktop preferences and local JSON profiles can be managed by the NixOS
module. Every setting defaults to `null`, which preserves the value managed by
the application. An explicit value is reapplied whenever the desktop process
starts.

```nix
programs.sing-box-for-desktop = {
  enable = true;

  settings = {
    startAtLogin = true;
    tray = {
      enable = true;
      keepInBackground = true;
    };
    language = "en"; # auto, en, zh-Hans, zh-Hant, fa, or ru
    appearance = "dark"; # auto, light, or dark
    theme = "blue"; # preset or lowercase #rrggbb

    terminal = {
      lightTheme = "Alabaster";
      darkTheme = "Afterglow";
      fontFamily = "Iosevka";
      fontSize = 14;
      alwaysShowSymbolBar = true;

      # Set the corresponding theme name to "" to select a custom theme.
      darkCustomTheme = {
        background = "#101010";
        foreground = "#eeeeee";
        cursor = "#eeeeee";
      };
    };

    core = {
      insecureMode = false;
      disableDeprecatedWarnings = true;
    };
  };

  profiles = [
    {
      name = "Default";
      configurationPath = "/run/secrets/sing-box.json";
    }
  ];
  defaultProfile = "Default";
};
```

Setting `profiles` to a list makes that list authoritative; `profiles = [ ];`
clears user profiles on launch, while the default `null` leaves them untouched.
Each `configurationPath` must be an absolute runtime path readable by the
desktop user. Only the path is placed in the Nix store; the JSON contents are
read when the application launches, so secret-bearing profiles can come from a
runtime secret manager. See [configuration storage](docs/configuration-storage.md)
for the exact database, file, and reconciliation behavior.

### Secret profile permissions

If `configurationPath` points to a file decrypted by sops-nix, create a
dedicated `sing-box` group and explicitly grant the desktop user access:

```nix
{ config, ... }:

{
  users.groups.sing-box = { };
  users.users.alice.extraGroups = [ "sing-box" ];

  sops.secrets."sing-box-profile" = {
    group = "sing-box";
    mode = "0440";
  };

  programs.sing-box-for-desktop.profiles = [
    {
      name = "Default";
      configurationPath = config.sops.secrets."sing-box-profile".path;
    }
  ];
}
```

Replace `alice` with the user who runs the desktop application, then start a
new login session so the supplementary group membership takes effect. Do not
make a secret world-readable.

For a configuration extracted into another restricted directory, assign the
file to the `sing-box` group with read permission (`0440`). Every parent
directory must also grant the group search (`x`) permission, for example mode
`0750`; access to the file alone is insufficient if the user cannot traverse
its directory. Apply the equivalent of:

```console
sudo chgrp sing-box /restricted/directory /restricted/directory/config.json
sudo chmod 0750 /restricted/directory
sudo chmod 0440 /restricted/directory/config.json
```

## Overlay

The default overlay exposes `pkgs.sing-box-for-desktop` on every supported
platform and also exposes `pkgs.sing-box-for-apple` on Darwin:

```nix
nixpkgs.overlays = [ inputs.sfd-nix.overlays.default ];
environment.systemPackages = [ pkgs.sing-box-for-desktop ];
```

On Linux, using only the overlay does not configure the privileged daemon;
prefer the NixOS module for a complete installation. On Darwin, prefer the
upstream installer as described above.

## Development

Enter the reproducible development shell with `devenv shell` (or allow the
included `.envrc`). It provides Cachix, Just, and uv. Common commands are
available through the `justfile`:

```console
just check
just check-all
just build
just run
```

## Binary cache

The flake advertises the public `sfd-nix.cachix.org` substituter and its signing
key. Pass `--accept-flake-config` when invoking the flake directly so Nix may use
it. The devenv shell configures the same cache automatically.

To upload validated desktop and daemon outputs, authenticate with a per-cache
write token using `CACHIX_AUTH_TOKEN` or `cachix authtoken`, then run:

```console
just cache-doctor
just cache-push
```

Never commit a Cachix auth token or private signing key. `just cache-push` first
runs the native flake checks, then pushes both release closures to the cache.

The Forgejo workflow in `.forgejo/workflows/cache.yaml` performs the same
validation and builds automatically on pushes to `main` using a runner labeled
`nixos-latest`. Add a per-cache write token as the repository Actions secret
`CACHIX_AUTH_TOKEN`; the workflow passes it directly to Cachix and never stores
it in the repository.

Useful outputs are:

- `packages.<linux-system>.sing-box-for-desktop` — the Linux desktop package
- `packages.<linux-system>.sing-box-daemon` — the matching Linux `boxdd` daemon
- `packages.aarch64-darwin.sing-box-for-apple` — the signed Apple client and installer
- `packages.aarch64-darwin.sing-box-for-desktop` — alias for the Apple client
- `nixosModules.default` — Linux-only declarative desktop/service integration
- `overlays.default` — the package overlay

On Linux, run `just check` (or `nix flake check --accept-flake-config`) to build
the desktop and daemon outputs. The Electron UI, both pnpm dependency graphs,
the Go daemon, and Cronet are built or fetched through fixed-output Nix
derivations; the Linux build does not download upstream `.deb` or RPM
artifacts. The Darwin output repacks the official Apple installer for the
signing reasons described above.

## License

The `sfd-nix` packaging and module code in this repository is licensed under
the GNU General Public License v3.0 or later (`GPL-3.0-or-later`). See
[LICENSE](LICENSE) for the complete license text.

Packaged upstream projects retain their own copyright notices and license
terms. See their repositories for details.
