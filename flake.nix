
{
  description = "Dock2";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            swift
            python3
            tree
          ];

          shellHook = ''
            export SDKROOT=$(xcrun --show-sdk-path)
            
            VENV_DIR=".venv"
            if [ ! -d "$VENV_DIR" ]; then
              python3 -m venv $VENV_DIR
            fi
            source $VENV_DIR/bin/activate
            
            echo "-- Dock2 dev environment --"
            echo "SDKROOT=$SDKROOT"
            echo "VENV_DIR=$VENV_DIR"
          '';
        };
      }
    );
}
