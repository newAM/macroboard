{ lib, rustPlatform, libevdev }:

let
  cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
in
rustPlatform.buildRustPackage {
  inherit (cargoToml.package) version;
  pname = cargoToml.package.name;

  src = ./.;

  cargoLock.lockFile = ./Cargo.lock;

  preBuild = ''
    export RUSTFLAGS="-D warnings"
    export LIBEVDEV_LIB_DIR=${libevdev}/lib
  '';

  builtInputs = [ libevdev ];

  doCheck = false;

  meta = with lib; {
    inherit (cargoToml.package) description;
    homepage = cargoToml.package.repository;
    licenses = with licenses; [ mit ];
  };
}
