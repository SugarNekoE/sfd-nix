{
  lib,
  nixosModule,
  nixosSystem,
  package,
  pkgs,
}:

let
  defaultProfileId = builtins.hashString "sha256" "Default";
  workProfileId = builtins.hashString "sha256" "Work";

  evaluated = nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      nixosModule
      {
        boot.isContainer = true;
        system.stateVersion = "26.05";
        programs.sing-box-for-desktop = {
          enable = true;
          inherit package;
          settings = {
            startAtLogin = true;
            tray = {
              enable = false;
              keepInBackground = false;
            };
            language = "zh-Hans";
            appearance = "dark";
            theme = "#112233";
            terminal = {
              lightTheme = "";
              darkTheme = "Afterglow";
              lightCustomTheme = {
                background = "#ffffff";
                foreground = "#111111";
              };
              darkCustomTheme = {
                background = "#111111";
                foreground = "#eeeeee";
              };
              fontFamily = "Iosevka";
              fontSize = 15;
              alwaysShowSymbolBar = true;
            };
            core = {
              insecureMode = true;
              disableDeprecatedWarnings = true;
            };
          };
          profiles = [
            {
              name = "Default";
              configuration = {
                log.level = "info";
                inbounds = [ ];
                outbounds = [ ];
              };
            }
            {
              name = "Work";
              configuration.log.level = "warn";
            }
          ];
          defaultProfile = "Default";
        };
      }
    ];
  };

  evaluatedDefaults = nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [
      nixosModule
      {
        boot.isContainer = true;
        system.stateVersion = "26.05";
        programs.sing-box-for-desktop = {
          enable = true;
          inherit package;
          settings = {
            startAtLogin = false;
            language = "auto";
            theme = "default";
          };
        };
      }
    ];
  };

  findConfiguredPackage =
    systemPackages:
    lib.findFirst (
      candidate: lib.hasPrefix "sing-box-for-desktop-configured" candidate.name
    ) (throw "configured package not found") systemPackages;

  configuredPackage = findConfiguredPackage evaluated.config.environment.systemPackages;
  defaultsConfiguredPackage = findConfiguredPackage (
    evaluatedDefaults.config.environment.systemPackages
  );

  autostart = evaluated.config.environment.etc."xdg/autostart/sing-box.desktop".text;
  autostartExec = lib.findFirst (
    line: lib.hasPrefix "Exec=" line
  ) (throw "autostart Exec line not found") (lib.splitString "\n" autostart);
  service = evaluated.config.systemd.services.sing-box-daemon.serviceConfig;
in
assert autostartExec == "Exec=${configuredPackage}/bin/sing-box --start-at-login";
assert
  !(builtins.hasAttr "xdg/autostart/sing-box.desktop" evaluatedDefaults.config.environment.etc);
assert service.RuntimeDirectory == "sing-box-daemon";
assert service.ProtectSystem == "strict";
assert lib.hasSuffix "service --working-directory /var/lib/sing-box-daemon set-insecure-mode true"
  service.ExecStartPre;
pkgs.runCommand "sing-box-for-desktop-module-check"
  {
    nativeBuildInputs = [ pkgs.jq ];
  }
  ''
    wrapper=${configuredPackage}/bin/sing-box
    grep -F "SING_BOX_LAUNCHER='${configuredPackage}/bin/sing-box'" "$wrapper"
    grep -F "SING_BOX_MANAGED_OPEN_AT_LOGIN='true'" "$wrapper"
    grep -F 'export SING_BOX_LAUNCHER=''${SING_BOX_LAUNCHER-' \
      "${configuredPackage}/bin/.sing-box-wrapped"

    managed_path="$(${pkgs.gnused}/bin/sed -n \
      "s/^export SING_BOX_MANAGED_CONFIGURATION='\([^']*\)'/\1/p" \
      "$wrapper")"
    test -n "$managed_path"

    jq -e \
      --arg defaultProfileId '${defaultProfileId}' \
      --arg workProfileId '${workProfileId}' \
      '
        .version == 1 and
        .openAtLogin == true and
        .removePreferences == [] and
        .preferences == {
          "accent": "#112233",
          "disable-deprecated-warnings": true,
          "language": "zh-Hans",
          "theme": "dark",
          "tray_enabled": false,
          "tray_in_background": false
        } and
        .terminal == {
          "darkThemeCustom": "{\"background\":\"#111111\",\"foreground\":\"#eeeeee\"}",
          "darkThemeName": "Afterglow",
          "fontFamily": "Iosevka",
          "fontSize": 15,
          "lightThemeCustom": "{\"background\":\"#ffffff\",\"foreground\":\"#111111\"}",
          "lightThemeName": "",
          "symbolBarAlwaysShow": true
        } and
        .selectedProfileId == $defaultProfileId and
        (.profiles | length) == 2 and
        .profiles[0] == {
          "configuration": {
            "inbounds": [],
            "log": { "level": "info" },
            "outbounds": []
          },
          "id": $defaultProfileId,
          "name": "Default"
        } and
        .profiles[1] == {
          "configuration": { "log": { "level": "warn" } },
          "id": $workProfileId,
          "name": "Work"
        }
      ' "$managed_path"

    defaults_wrapper=${defaultsConfiguredPackage}/bin/sing-box
    grep -F "SING_BOX_MANAGED_OPEN_AT_LOGIN='false'" "$defaults_wrapper"
    defaults_managed_path="$(${pkgs.gnused}/bin/sed -n \
      "s/^export SING_BOX_MANAGED_CONFIGURATION='\([^']*\)'/\1/p" \
      "$defaults_wrapper")"
    test -n "$defaults_managed_path"
    jq -e '
      .version == 1 and
      .openAtLogin == false and
      .preferences == {} and
      .removePreferences == ["language", "accent"] and
      .terminal == {} and
      (.profiles == null) and
      (.selectedProfileId == null)
    ' "$defaults_managed_path"

    touch "$out"
  ''
