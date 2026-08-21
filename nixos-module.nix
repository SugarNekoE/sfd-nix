{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.sing-box-for-desktop;
  daemon = "${cfg.package}/share/sing-box-for-desktop/resources/daemon/sing-box-daemon";
in
{
  options.programs.sing-box-for-desktop = {
    enable = lib.mkEnableOption "the sing-box Linux desktop client and its system daemon";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The sing-box-for-desktop package to install and run.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    environment.etc."polkit-1/actions/io.nekohasekai.sfl.policy".source =
      "${cfg.package}/share/polkit-1/actions/io.nekohasekai.sfl.policy";

    security.polkit = {
      enable = true;
      enablePkexecWrapper = lib.mkDefault true;
    };

    systemd.services.sing-box-daemon = {
      description = "sing-box desktop service";
      documentation = [ "https://github.com/SagerNet/sing-box-for-desktop" ];
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [
        "network-online.target"
        "dbus.service"
        "polkit.service"
      ];
      path = [
        pkgs.systemd
        pkgs.xdg-utils
      ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${daemon} run --working-directory /var/lib/sing-box-daemon --socket /run/sing-box.socket";
        StateDirectory = "sing-box-daemon";
        StateDirectoryMode = "0700";
        UMask = "0077";
        Restart = "always";
        RestartSec = 5;
        LimitNOFILE = 1048576;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
      };
    };
  };
}
