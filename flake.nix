{
  description = "remote-mouse packaged + NixOS module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    system = "x86_64-linux";

    pkgs = import nixpkgs {
      inherit system;
      config = { allowUnfree = true; };
    };

    lib      = pkgs.lib;
    stdenv   = pkgs.stdenv;
    fetchzip = pkgs.fetchzip;

    # path list for rpath
    runtimeLibPath = lib.makeLibraryPath [
      pkgs.glib pkgs.dbus pkgs.zlib pkgs.freetype pkgs.fontconfig
      pkgs.libxkbcommon pkgs.libGL pkgs.alsa-lib
      stdenv.cc.cc.lib stdenv.cc.libc
      pkgs.xorg.libX11 pkgs.xorg.libXext pkgs.xorg.libXrender
      pkgs.xorg.libXtst pkgs.xorg.libXi pkgs.xorg.libXcursor
      pkgs.xorg.libXrandr pkgs.xorg.libSM pkgs.xorg.libICE
      pkgs.xorg.libxcb pkgs.xorg.xcbutil pkgs.xorg.xcbutilwm
      pkgs.xorg.xcbutilimage pkgs.xorg.xcbutilkeysyms
      pkgs.xorg.xcbutilrenderutil pkgs.xorg.xcbutilcursor
    ];

    # optional xdotool wrapper
    xdoPath = lib.optionalString (pkgs.xdotool != null)
      (lib.makeBinPath [ pkgs.xdotool ]);

    # 1) build the proprietary RemoteMouse binary
    remoteMouseDrv = stdenv.mkDerivation rec {
      pname    = "remotemouse";
      version  = "2023-01-25";

      src = fetchzip {
        url       = "https://www.remotemouse.net/downloads/linux/RemoteMouse_x86_64.zip";
        hash      = "sha256-kmASvBKJW9Q1Z7ivcuKpZTBZA9LDWaHQerqMcm+tai4=";
        stripRoot = false;
      };

      nativeBuildInputs = [ pkgs.makeWrapper pkgs.patchelf ];
      dontPatchELF = true;
      dontStrip    = true;

      installPhase = ''
        mkdir -p $out/opt/remotemouse
        cp -r RemoteMouse lib images $out/opt/remotemouse/

        # shell vars for vendored libs
        vendorLib="$out/opt/remotemouse/lib"
        vendorQtLib="$vendorLib/PyQt5/Qt5/lib"
        vendorQtPlugins="$vendorLib/PyQt5/Qt5/plugins"
        vendorQtQml="$vendorLib/PyQt5/Qt5/qml"

        # desktop entry
        mkdir -p $out/share/applications
        cat > $out/share/applications/remotemouse.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Remote Mouse
Comment=Control this PC from your phone
Exec=remotemouse
Icon=remotemouse
Terminal=false
Categories=Utility;
EOF

        # icon
        if [ -f images/RemoteMouse.png ]; then
          mkdir -p $out/share/pixmaps
          cp images/RemoteMouse.png $out/share/pixmaps/remotemouse.png
        fi

        # wrapper
        mkdir -p $out/bin
        makeWrapper $out/opt/remotemouse/RemoteMouse $out/bin/remotemouse \
          --chdir $out/opt/remotemouse \
          --prefix LD_LIBRARY_PATH : "$vendorLib:$vendorQtLib:${runtimeLibPath}" \
          --set PYTHONHOME "$vendorLib" \
          --set PYTHONPATH "$vendorLib" \
          --set QT_PLUGIN_PATH "$vendorQtPlugins" \
          --set QT_QPA_PLATFORM_PLUGIN_PATH "$vendorQtPlugins/platforms" \
          --set QML2_IMPORT_PATH "$vendorQtQml" \
          ${lib.optionalString (xdoPath != "") ("--prefix PATH : " + xdoPath)}
      '';

      postFixup = ''
        echo "Patching RemoteMouse ELF..."
        patchelf \
          --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
          --set-rpath "$vendorLib:$vendorQtLib:${runtimeLibPath}" \
          $out/opt/remotemouse/RemoteMouse || true

        for so in $out/opt/remotemouse/lib/*.so*; do
          [ -e "$so" ] || continue
          patchelf --set-rpath "$vendorLib:$vendorQtLib:${runtimeLibPath}" "$so" || true
        done
      '';

      meta = with lib; {
        description = "Remote Mouse proprietary binary for NixOS";
        license     = licenses.unfreeRedistributable;
        platforms   = [ "x86_64-linux" ];
      };
    };

    # 2) export an overlay so pkgs.remotemouse is available
    overlay = final: prev: {
      remotemouse = remoteMouseDrv;
    };
  in {
    # allow `nix build .` to work
    defaultPackage.${system} = remoteMouseDrv;

    # NixOS module for `nixos-rebuild`
    nixosModules.remotemouse = { config, lib, pkgs, ... }: {
      config = {
        # bring in our overlay
        nixpkgs.overlays        = [ overlay ];

        # runtime settings
        nixpkgs.config.allowUnfree = true;
        environment.systemPackages = [
          pkgs.remotemouse
          pkgs.xorg.xhost
        ];
        networking.firewall.allowedTCPPorts = [ 1978 ];
        networking.firewall.allowedUDPPorts = [ 1978 ];
      };
    };
  };
}
