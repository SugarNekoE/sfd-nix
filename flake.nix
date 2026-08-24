{
  description = "sfd-nix: Nix packaging for the sing-box desktop clients";

  nixConfig = {
    extra-substituters = [ "https://sfd-nix.cachix.org" ];
    extra-trusted-public-keys = [
      "sfd-nix.cachix.org-1:SX5EpvFvgFZXgG94/0fX1L+lUWQ90dPq0Ieor7/rDig="
    ];
  };

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/master";

  outputs =
    { self, nixpkgs }:
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
        pkgs.callPackage (
          if pkgs.stdenv.hostPlatform.isDarwin then ./package-darwin.nix else ./package.nix
        ) { };
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
          package = final.callPackage (if isDarwin then ./package-darwin.nix else ./package.nix) { };
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
