# remotemouse

Remote Mouse on NixOS

Note: Only works on X11 (Not Wayland)

https://www.remotemouse.net/

Installation:

Add this repo to your flake.nix:

inputs = {
  remotemouse.url = "github:dectech-au/remotemouse"
  remotemouse.inputs.nixpkgs.follows = "nixpkgs";
};

then add the module to your imports:

outputs = { self, nixpkgs, remotemouse, ... }: {
  imports = [ remotemouse.nixosModules.remotemouse ];

then rebuild, and enjoy.
