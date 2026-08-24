{
  lib,
  stdenvNoCC,
  fetchurl,
  xar,
  pbzx,
  cpio,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "sing-box-for-apple";
  version = "1.14.0-rc.1";

  src = fetchurl {
    url = "https://github.com/SagerNet/sing-box/releases/download/v${finalAttrs.version}/SFM-${finalAttrs.version}-Apple.pkg";
    hash = "sha256-JwTrKjN2aHSZEwHOCzqTAGOWMSab6sNyic+rNdvDE00=";
  };

  dontUnpack = true;
  strictDeps = true;

  nativeBuildInputs = [
    xar
    pbzx
    cpio
  ];

  installPhase = ''
    runHook preInstall

    mkdir extracted
    cd extracted
    xar -xf "$src"

    mkdir -p \
      "$out/Applications" \
      "$out/bin" \
      "$out/share/licenses/sing-box-for-apple" \
      "$out/share/sing-box-for-apple"

    cd "$out/Applications"
    pbzx -n "$NIX_BUILD_TOP/extracted/component-arm64.pkg/Payload" \
      | cpio -idm --no-absolute-filenames

    ln -s "$out/Applications/SFM.app/Contents/MacOS/SFM" \
      "$out/bin/sing-box"
    ln -s "$src" "$out/share/sing-box-for-apple/SFM.pkg"
    install -Dm644 "$NIX_BUILD_TOP/extracted/Resources/LICENSE" \
      "$out/share/licenses/sing-box-for-apple/LICENSE"

    runHook postInstall
  '';

  # Rewriting Mach-O files would invalidate upstream's signatures. The app,
  # system extension, and privileged helper must remain byte-for-byte intact.
  dontFixup = true;

  passthru = {
    installer = finalAttrs.src;
    sourceRevision = "becbc5fdaa08bc5bebe810f95df2ff9638ad542f";
  };

  meta = {
    description = "macOS client for the sing-box universal proxy platform";
    homepage = "https://github.com/SagerNet/sing-box-for-apple";
    license = lib.licenses.gpl3Plus;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    mainProgram = "sing-box";
    platforms = [ "aarch64-darwin" ];
  };
})
