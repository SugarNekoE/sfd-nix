# sing-box-for-desktop for Nix

This flake packages [SagerNet/sing-box-for-desktop](https://github.com/SagerNet/sing-box-for-desktop), the experimental Linux desktop client for sing-box.

The build is pinned to desktop version `1.14.0-beta.17` at revision `5536324bb2b2466a0817ad6e4a1313d0a6486910`. Upstream has not published desktop tags or releases yet, so the exact source revision and its recursive dashboard submodules are pinned in the package.

## Run or build

```console
nix build .#sing-box-for-desktop
nix run .
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

This installs the desktop entry and PolicyKit action, enables `pkexec`, and starts `sing-box-daemon.service`. The daemon socket is `/run/sing-box.socket`; daemon state is stored in `/var/lib/sing-box-daemon`.

## Overlay

The default overlay exposes `pkgs.sing-box-for-desktop`:

```nix
nixpkgs.overlays = [ inputs.sfd-nix.overlays.default ];
environment.systemPackages = [ pkgs.sing-box-for-desktop ];
```

Using only the overlay does not configure the privileged daemon. Prefer the NixOS module for a complete installation.

## Development

Useful outputs are:

- `packages.<system>.sing-box-for-desktop` — the complete desktop package
- `packages.<system>.sing-box-daemon` — the matching `boxdd` daemon
- `nixosModules.default` — declarative desktop/service integration
- `overlays.default` — the package overlay

Run `nix flake check` to build both package outputs. The Electron UI, both pnpm dependency graphs, the Go daemon, and Cronet are built or fetched through fixed-output Nix derivations; the build does not download upstream `.deb` or RPM artifacts.

The packaged upstream projects are licensed under GPL-3.0-or-later. See their repositories for the complete license text.
