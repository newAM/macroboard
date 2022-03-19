fn main() {
    println!("cargo:rerun-if-env-changed=LIBEVDEV_LIB_DIR");
    println!("cargo:rustc-link-lib=dylib=evdev");
    println!(
        "cargo:rustc-link-search={}",
        std::env::var("LIBEVDEV_LIB_DIR").expect("LIBEVDEV_LIB_DIR is not set")
    );
}
