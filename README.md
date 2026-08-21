# sfd-nix

This flake packages [SagerNet/sing-box-for-desktop](https://github.com/SagerNet/sing-box-for-desktop), the experimental Linux desktop client for sing-box.

The build is pinned to desktop version `1.14.0-beta.17` at revision `5536324bb2b2466a0817ad6e4a1313d0a6486910`. Upstream has not published desktop tags or releases yet, so the exact source revision and its recursive dashboard submodules are pinned in the package.

## Run or build

```console
nix build --accept-flake-config .#sing-box-for-desktop
nix run --accept-flake-config .
```

The package currently supports `x86_64-linux` and `aarch64-linux`. It uses the
upstream-matched Node.js 26.7, Electron 43.3, and sing-box 1.14.0-beta.17
toolchain rather than repacking an upstream distribution archive.

The standalone package contains the UI and its matching daemon, but a normal user cannot install the required system service. On NixOS, use the module for a working client:

```nix
{
  inputs.sfd-nix.url = "github:YOUR-USER/sfd-nix";

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
      configuration = builtins.fromJSON (builtins.readFile ./sing-box.json);
    }
  ];
  defaultProfile = "Default";
};
```

Setting `profiles` to a list makes that list authoritative; `profiles = [ ];`
clears user profiles on launch, while the default `null` leaves them untouched.
Declarative profile data is copied through the world-readable Nix store and
must not contain secrets. See [configuration storage](docs/configuration-storage.md)
for the exact database, file, and reconciliation behavior.

## Overlay

The default overlay exposes `pkgs.sing-box-for-desktop`:

```nix
nixpkgs.overlays = [ inputs.sfd-nix.overlays.default ];
environment.systemPackages = [ pkgs.sing-box-for-desktop ];
```

Using only the overlay does not configure the privileged daemon. Prefer the NixOS module for a complete installation.

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

Useful outputs are:

- `packages.<system>.sing-box-for-desktop` — the complete desktop package
- `packages.<system>.sing-box-daemon` — the matching `boxdd` daemon
- `nixosModules.default` — declarative desktop/service integration
- `overlays.default` — the package overlay

Run `just check` (or `nix flake check --accept-flake-config`) to build both
package outputs. The Electron UI, both pnpm dependency graphs, the Go daemon,
and Cronet are built or fetched through fixed-output Nix derivations; the build
does not download upstream `.deb` or RPM artifacts.

## License

The `sfd-nix` packaging and module code in this repository is licensed under
the GNU General Public License v3.0 or later (`GPL-3.0-or-later`). See
[LICENSE](LICENSE) for the complete license text.

Packaged upstream projects retain their own copyright notices and license
terms. See their repositories for details.
