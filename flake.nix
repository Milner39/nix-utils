{
  inputs = {
    nixpkgs.url      =  "github:nixos/nixpkgs/nixos-25.05";
    flake-utils.url  =  "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... } @ inputs: (
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
      in {
        lib = import ./lib { inherit pkgs lib; };
      }
    )
  );
}