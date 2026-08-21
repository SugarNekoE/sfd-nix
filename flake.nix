{
  description = "sfd-nix: Nix packaging for sing-box-for-desktop";

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
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      packageFor =
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.callPackage ./package.nix { };
    in
    {
      packages = forAllSystems (
        system:
        let
          package = packageFor system;
        in
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

      overlays.default = final: _prev: {
        sing-box-for-desktop = final.callPackage ./package.nix { };
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
