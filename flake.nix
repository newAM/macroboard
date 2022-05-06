{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    nixpkgs.lib.recursiveUpdate
      (flake-utils.lib.eachSystem [
        "x86_64-linux"
        "aarch64-linux"
      ]
        (system:
          let
            pkgs = nixpkgs.legacyPackages.${system};
          in
          rec {
            devShells.default = pkgs.mkShell {
              inputsFrom = [ packages.default ];
              shellHook = ''
                export LIBEVDEV_LIB_DIR=${pkgs.libevdev}/lib
              '';
            };

            packages.default = pkgs.callPackage ./package.nix { };

            apps = {
              bindgen =
                let
                  bindgenScript = pkgs.writeShellScript "libevdev-bindgen.sh" ''
                    ${pkgs.rust-bindgen}/bin/bindgen \
                      ${pkgs.libevdev}/include/libevdev-1.0/libevdev/libevdev.h \
                      -o src/bindings.rs
                  '';
                in
                {
                  program = "${bindgenScript}";
                  type = "app";
                };
            };
          }
        ))
      {
        overlays.default = final: prev: {
          macroboard = self.packages.${prev.system}.default;
        };
        nixosModules.default = import ./module.nix;
      };
}
