{
  lib,
  buildGo126Module,
  buildPackages,
  cronet-go,
  fetchFromGitHub,
  systemd,
}:

buildGo126Module (finalAttrs: {
  pname = "sing-box-daemon";
  version = "1.14.0-rc.1";

  src = fetchFromGitHub {
    owner = "SagerNet";
    repo = "sing-box";
    tag = "v${finalAttrs.version}";
    hash = "sha256-SMFPB3ab2Y/Aakbgnaz1iDp0ZF+iHE3BOvoRojII9Cc=";
  };

  vendorHash = "sha256-ea9oaMryf4qEc3bjkEzFN+Rt8djnhM8AqmKUG65xCVc=";

  tags = [
    "with_gvisor"
    "with_quic"
    "with_dhcp"
    "with_wireguard"
    "with_utls"
    "with_acme"
    "with_clash_api"
    "with_tailscale"
    "with_ccm"
    "with_ocm"
    "with_cloudflared"
    "with_naive_outbound"
    "with_usbip"
    "with_openvpn"
    "with_openconnect"
    "badlinkname"
    "tfogo_checklinkname0"
  ];

  subPackages = [ "experimental/boxdd" ];

  env = {
    CGO_ENABLED = 1;
    CGO_LDFLAGS = "-fuse-ld=lld";
  };

  nativeBuildInputs = [ buildPackages.rustc.llvmPackages.bintools ];
  buildInputs = [ cronet-go ];

  ldflags = [
    "-X=github.com/sagernet/sing-box/constant.Version=${finalAttrs.version}"
    "-X=runtime.godebugDefault=multipathtcp=0,tlssha1=1,tlsunsafeekm=1"
    "-checklinkname=0"
    "-s"
    "-w"
  ];

  postPatch = ''
    substituteInPlace experimental/boxdd/cmd_service_linux.go \
      --replace-fail 'exec.Command("systemctl",' 'exec.Command("${systemd}/bin/systemctl",'
  '';

  postConfigure = ''
    pushd vendor/github.com/sagernet/cronet-go
    chmod -R u+w .
    cp -r ${cronet-go}/. .
    patch -p1 < ${./patches/cronet-go.patch}
    substituteInPlace internal/cronet/loader_unix.go --subst-var out
    popd
  '';

  postInstall = ''
    mv "$out/bin/boxdd" "$out/bin/sing-box-daemon"
    install -Dm644 LICENSE "$out/share/licenses/sing-box-daemon/LICENSE"
  '';

  doCheck = false;

  meta = {
    description = "Privileged sing-box daemon for the desktop client";
    homepage = "https://github.com/SagerNet/sing-box";
    license = lib.licenses.gpl3Plus;
    mainProgram = "sing-box-daemon";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
