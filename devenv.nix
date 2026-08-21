{ pkgs, ... }:

let
  cachixCacheName = "sfd-nix";
in
{
  name = "sfd-nix";

  packages = with pkgs; [
    cachix
    just
    uv
  ];

  cachix.push = cachixCacheName;

  env.CACHIX_CACHE_NAME = cachixCacheName;

  git-hooks = {
    enable = true;
    hooks = {
      convco = {
        enable = true;
      };
    };
  };
}
