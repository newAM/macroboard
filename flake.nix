{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";
    crane.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    flake-utils,
  }:
    nixpkgs.lib.recursiveUpdate
    (flake-utils.lib.eachSystem ["x86_64-linux" "aarch64-linux"]
      (
        system: let
          pkgs = nixpkgs.legacyPackages.${system};
          cargoToml = nixpkgs.lib.importTOML ./Cargo.toml;
          craneLib = crane.lib.${system};

          src = craneLib.cleanCargoSource ./.;
          preBuild = "export LIBEVDEV_LIB_DIR=${pkgs.libevdev}/lib";

          cargoArtifacts = craneLib.buildDepsOnly {
            inherit src preBuild;
          };

          nixSrc = nixpkgs.lib.sources.sourceFilesBySuffices ./. [".nix"];
        in {
          devShells.default = pkgs.mkShell {
            inputsFrom = [self.packages.${system}.default];
            shellHook = preBuild;
          };

          packages.default = craneLib.buildPackage {
            inherit src preBuild cargoArtifacts;
          };

          checks = {
            pkgs = self.packages.${system}.default;

            clippy = craneLib.cargoClippy {
              inherit src preBuild cargoArtifacts;
            };

            rustfmt = craneLib.cargoFmt {inherit src;};

            alejandra = pkgs.runCommand "alejandra" {} ''
              ${pkgs.alejandra}/bin/alejandra --check ${nixSrc}
              touch $out
            '';
          };

          apps.bindgen = {
            program = "${pkgs.writeShellScript "libevdev-bindgen.sh" ''
              ${pkgs.rust-bindgen}/bin/bindgen \
                ${pkgs.libevdev}/include/libevdev-1.0/libevdev/libevdev.h \
                -o src/bindings.rs
            ''}";
            type = "app";
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
