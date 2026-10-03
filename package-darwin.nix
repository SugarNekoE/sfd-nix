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
  version = "1.14.2";

  src = fetchurl {
    url = "https://github.com/SagerNet/sing-box/releases/download/v${finalAttrs.version}/SFM-${finalAttrs.version}-Apple.pkg";
    hash = "sha256-H5Te8So+/LkUhhyEctPypooYFCxZ9OaeFVe5BCMiM8Y=";
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

  # Rewriting Mach-O files would invalidate upstream's signatures.
  dontFixup = true;

  passthru = {
    installer = finalAttrs.src;
    sourceRevision = "742a6d5e25c9f4f8b91773f0f7e516c1c850e46b";
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
