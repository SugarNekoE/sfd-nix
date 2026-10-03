{
  description = "sfd-nix: Nix packaging for the sing-box desktop clients";

  nixConfig = {
    extra-substituters = [ "https://sfd-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "sfd-nix.cachix.org-1:SX5EpvFvgFZXgG94/0fX1L+lUWQ90dPq0Ieor7/rDig="
    ];
  };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";
  # sing-box 1.14.2 requires cronet-go with the 4-argument
  # Cronet_Engine_SetUdpDialer ABI. The nixpkgs pin above predates that, so this
  # input supplies only the matching prebuilt cronet-go to the daemon while the
  # desktop toolchain (Node.js 26.7, pnpm 11.21, Electron 43.7) stays pinned.
  inputs.nixpkgs-cronet.url = "github:NixOS/nixpkgs/master";

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-cronet,
    }:
    let
      linuxSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      darwinSystems = [ "aarch64-darwin" ];
      supportedSystems = linuxSystems ++ darwinSystems;
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      packageFor =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        if pkgs.stdenv.hostPlatform.isDarwin then
          pkgs.callPackage ./package-darwin.nix { }
        else
          pkgs.callPackage ./package.nix {
            cronet-go = nixpkgs-cronet.legacyPackages.${system}.cronet-go;
          };
    in
    {
      packages = forAllSystems (
        system:
        let
          package = packageFor system;
        in
        if nixpkgs.lib.hasSuffix "-darwin" system then
          {
            default = package;
            sing-box-for-apple = package;
            sing-box-for-desktop = package;
          }
        else
          {
            default = package;
            sing-box-for-desktop = package;
            sing-box-daemon = package.passthru.daemon;
          }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        if pkgs.stdenv.hostPlatform.isDarwin then
          { package = self.packages.${system}.sing-box-for-apple; }
        else
          {
            package = self.packages.${system}.sing-box-for-desktop;
            daemon = self.packages.${system}.sing-box-daemon;
            module = pkgs.callPackage ./tests/module-check.nix {
              nixosModule = ./nixos-module.nix;
              inherit (nixpkgs.lib) nixosSystem;
              package = self.packages.${system}.sing-box-for-desktop;
            };
          }
      );

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);

      overlays.default =
        final: _prev:
        let
          isDarwin = final.stdenv.hostPlatform.isDarwin;
          system = final.stdenv.hostPlatform.system;
          package =
            if isDarwin then
              final.callPackage ./package-darwin.nix { }
            else
              final.callPackage ./package.nix {
                cronet-go = nixpkgs-cronet.legacyPackages.${system}.cronet-go;
              };
        in
        {
          sing-box-for-desktop = package;
        }
        // nixpkgs.lib.optionalAttrs isDarwin {
          sing-box-for-apple = package;
        };

      nixosModules.default =
        { lib, pkgs, ... }:
        {
          imports = [ ./nixos-module.nix ];
          programs.sing-box-for-desktop.package = lib.mkDefault (
            self.packages.${pkgs.stdenv.hostPlatform.system}.sing-box-for-desktop
          );
        };
      nixosModules.sing-box-for-desktop = self.nixosModules.default;
    };
}
