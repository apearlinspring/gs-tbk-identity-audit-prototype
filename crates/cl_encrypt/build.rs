use std::env;

fn main() {
    let manifest_dir = env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR is set by Cargo");
    println!("cargo:rustc-link-search=native={manifest_dir}");
    println!("cargo:rustc-link-lib=dylib=encrypt");
}
