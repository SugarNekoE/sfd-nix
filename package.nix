{
  lib,
  stdenv,
  callPackage,
  copyDesktopItems,
  electron_43-bin,
  fetchFromGitHub,
  fetchPnpmDeps,
  fetchurl,
  makeDesktopItem,
  makeWrapper,
  nodejs_26,
  nodejs-slim_26,
  pnpm_11,
  pnpmConfigHook,
}:

let
  electronVersion = "43.3.0";
  electronPlatform =
    {
      x86_64-linux = "linux-x64";
      aarch64-linux = "linux-arm64";
    }
    .${stdenv.hostPlatform.system};
  electronHash =
    {
      x86_64-linux = "f4987e9f045e46b117f0805d6ba4dc524e2abb2c2e33660f175bb39564bd3dae";
      aarch64-linux = "3e89a62c345d8171bf54f77df5b3d8216c492847eed00ae59cadd78d6f5535f7";
    }
    .${stdenv.hostPlatform.system};
  electron = electron_43-bin.overrideAttrs (
    finalElectronAttrs: previousElectronAttrs: {
      version = electronVersion;
      src = fetchurl {
        url = "https://github.com/electron/electron/releases/download/v${electronVersion}/electron-v${electronVersion}-${electronPlatform}.zip";
        sha256 = electronHash;
      };
      passthru = previousElectronAttrs.passthru // {
        dist = "${finalElectronAttrs.finalPackage}/libexec/electron";
      };
    }
  );
  pnpm = pnpm_11.override { nodejs-slim = nodejs-slim_26; };
  daemon = callPackage ./sing-box-daemon.nix { };
  version = "1.14.0-beta.17";
  source = fetchFromGitHub {
    owner = "SagerNet";
    repo = "sing-box-for-desktop";
    rev = "5536324bb2b2466a0817ad6e4a1313d0a6486910";
    fetchSubmodules = true;
    hash = "sha256-aia+jPRQPXwdRH0T132TTzU4klzneUm/Iw6LZWsWXQo=";
  };
  dashboardPnpmDeps = fetchPnpmDeps {
    pname = "sing-box-for-desktop-dashboard";
    inherit version pnpm;
    src = source;
    sourceRoot = "source/dashboard";
    fetcherVersion = 4;
    hash = "sha256-QbcvSwJh5v+h4rYPAzGAViQX/LRQAlQdA+oXrp5zq0o=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "sing-box-for-desktop";
  inherit version;

  src = source;

  patches = [
    ./patches/nix-resources-path.patch
    ./patches/use-nix-pnpm.patch
  ];

  pnpmDeps = fetchPnpmDeps {
    inherit (finalAttrs)
      pname
      version
      src
      patches
      ;
    inherit pnpm;
    fetcherVersion = 4;
    hash = "sha256-45ejBGIQyMJsTG8Ul2eu/cAuormA2NpG3idgaLEJS8I=";
  };

  nativeBuildInputs = [
    copyDesktopItems
    makeWrapper
    nodejs_26
    pnpm
    pnpmConfigHook
  ];

  env = {
    ELECTRON_SKIP_BINARY_DOWNLOAD = 1;
    SOURCE_DATE_EPOCH = "1786957667";
  };

  # The dependency FOD enforces upstream's release-age and trust policies while
  # it has registry access. The actual build then trusts that verified lockfile
  # so pnpm does not try to re-fetch registry metadata in the offline sandbox.
  postPatch = ''
    substituteInPlace pnpm-workspace.yaml dashboard/pnpm-workspace.yaml \
      --replace-fail \
        'trustPolicyIgnoreAfter: 259200' \
        $'trustPolicyIgnoreAfter: 259200\ntrustLockfile: true'
  '';

  postConfigure = ''
    rootPnpmDeps="$pnpmDeps"
    pnpmDeps=${dashboardPnpmDeps}
    pnpmRoot=dashboard
    pnpmConfigHook
    unset pnpmRoot
    pnpmDeps="$rootPnpmDeps"
  '';

  buildPhase = ''
    runHook preBuild

    pnpm -C dashboard generate

    applicationRoot="$PWD"
    pushd ${daemon.src}
    PATH="$applicationRoot/node_modules/.bin:$PATH" \
      "$applicationRoot/node_modules/.bin/buf" generate \
      --template "$applicationRoot/buf.gen.yaml" \
      --output "$applicationRoot" \
      . \
      --path experimental/boxdd/desktop_service.proto \
      --path daemon/started_service.proto \
      --path daemon/managed_service.proto
    popd

    pnpm exec electron-vite build

    install -Dm755 ${lib.getExe daemon} bin/sing-box-daemon
    cp -r ${electron.dist} electron-dist
    chmod -R u+w electron-dist

    pnpm exec electron-builder \
      --dir \
      --config electron-builder.yml \
      --config.electronDist=electron-dist \
      --config.electronVersion=${electron.version} \
      --config.extraMetadata.version=${finalAttrs.version} \
      --config.npmRebuild=false \
      --publish never

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p \
      "$out/bin" \
      "$out/lib/systemd/system" \
      "$out/share/sing-box-for-desktop"
    cp -r release/linux*-unpacked/resources "$out/share/sing-box-for-desktop/"

    makeWrapper ${lib.getExe electron} "$out/bin/sing-box" \
      --inherit-argv0 \
      --set ELECTRON_FORCE_IS_PACKAGED 1 \
      --add-flags "$out/share/sing-box-for-desktop/resources/app.asar" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    install -Dm644 resources/icons/512x512.png \
      "$out/share/icons/hicolor/512x512/apps/sing-box.png"
    install -Dm644 resources/icons/1024x1024.png \
      "$out/share/icons/hicolor/1024x1024/apps/sing-box.png"
    install -Dm644 build/io.nekohasekai.sfl.policy \
      "$out/share/polkit-1/actions/io.nekohasekai.sfl.policy"
    install -Dm644 build/io.nekohasekai.sfl.metainfo.xml \
      "$out/share/metainfo/io.nekohasekai.sfl.metainfo.xml"
    install -Dm644 LICENSE \
      "$out/share/licenses/sing-box-for-desktop/LICENSE"

    substitute build/sing-box-daemon.service \
      "$out/lib/systemd/system/sing-box-daemon.service" \
      --replace-fail "/opt/sing-box/resources/daemon/sing-box-daemon" \
        "$out/share/sing-box-for-desktop/resources/daemon/sing-box-daemon"

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "sing-box";
      desktopName = "sing-box";
      genericName = "SingBox Desktop Client";
      comment = "Linux client for the sing-box universal proxy platform";
      exec = "sing-box %U";
      icon = "sing-box";
      startupWMClass = "sing-box";
      categories = [ "Network" ];
      mimeTypes = [
        "application/x-sing-box-profile"
        "x-scheme-handler/sing-box"
      ];
    })
  ];

  passthru = {
    inherit daemon dashboardPnpmDeps;
    sourceRevision = finalAttrs.src.rev;
    dashboardRevision = "4f29dcc7b93292c6311e92dc367670dd594db794";
  };

  meta = {
    description = "Linux desktop client for the sing-box universal proxy platform";
    homepage = "https://github.com/SagerNet/sing-box-for-desktop";
    license = lib.licenses.gpl3Plus;
    mainProgram = "sing-box";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
