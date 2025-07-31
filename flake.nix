{
  description = "remote-mouse packaged + NixOS module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
  };

  outputs = { self, nixpkgs, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs   = import nixpkgs { inherit system; };

    # 1) define the package
    remoteMouseDrv = pkgs.stdenv.mkDerivation rec {
      pname    = "remotemouse";
      version  = "2023-01-25";
      src      = pkgs.fetchzip {
        url       = "https://www.remotemouse.net/downloads/linux/RemoteMouse_x86_64.zip";
        hash      = "sha256-kmASvBKJW9Q1Z7ivcuKpZTBZA9LDWaHQerqMcm+tai4=";
        stripRoot = false;
      };

      nativeBuildInputs = [ pkgs.makeWrapper pkgs.patchelf ];
      dontPatchELF     = true;
      dontStrip        = true;

      installPhase = ''
        mkdir -p $out/opt/remotemouse
        cp -r RemoteMouse lib images $out/opt/remotemouse/
        # …your wrapper + patchelf bits here…
      '';

      meta = with pkgs.lib; {
        description = "Remote Mouse proprietary binary for NixOS";
        license     = licenses.unfreeRedistributable;
        platforms   = [ "x86_64-linux" ];
      };
    };

    # 2) overlay so `pkgs.remotemouse` exists
    overlay = final: prev: {
      remotemouse = remoteMouseDrv;
    };
  in {
    # make it buildable via `nix build`
    defaultPackage.${system} = remoteMouseDrv;

    # expose a NixOS module
    nixosModules.remotemouse = { config, lib, pkgs, … }: {
      config = {
        # ← everything goes in here
        nixpkgs.overlays          = [ overlay ];  
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
