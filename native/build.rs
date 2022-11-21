use std::path::PathBuf;

use dart_bindgen::{config::*, Codegen};

fn main() {
    let crate_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
    let mut config = cbindgen::Config {
        language: cbindgen::Language::C,
        ..Default::default()
    };
    config.braces = cbindgen::Braces::SameLine;
    config.cpp_compat = true;
    config.style = cbindgen::Style::Both;
    cbindgen::Builder::new()
        .with_crate(crate_dir)
        .with_config(config)
        .generate()
        .expect("Unable to generate bindings")
        .write_to_file("binding.h");
    let config = DynamicLibraryConfig {
        ios: DynamicLibraryCreationMode::Executable.into(),
        android: DynamicLibraryCreationMode::open("libnative.so").into(),
        ..Default::default()
    };
    // load the c header file, with config and lib name
    let codegen = Codegen::builder()
        .with_src_header("binding.h")
        .with_lib_name("libnative")
        .with_config(config)
        .with_allo_isolate()
        .build()
        .unwrap();
    // generate the dart code and get the bindings back
    let bindings = codegen.generate().unwrap();
    // write the bindings to your dart package
    // and start using it to write your own high level abstraction.
    bindings.write_to_file("../lib/ffi.dart").unwrap();

    // fix __extenddftf2 runtime error
    // https://github.com/android/ndk/issues/1614
    let host_arch = std::env::var("HOST").unwrap();

    let ndk_host_arch = match host_arch.as_str() {
        "x86_64-unknown-linux-gnu" => Some("linux-x86_64"),
        "x86_64-apple-darwin" => Some("darwin-x86_64"),
        _ => None,
    };
    let target_arch = std::env::var("TARGET").unwrap();

    // only x86_64 builds have this error
    let ndk_target_arch = match target_arch.as_str() {
        "x86_64-linux-android" => Some("x86_64"),
        _ => None,
    };

    match (ndk_host_arch, ndk_target_arch) {
        (Some(host), Some(target)) => {
            let llvm_lib_dir =
                PathBuf::from(std::env::var("CARGO_NDK_CMAKE_TOOLCHAIN_PATH").unwrap())
                    .parent()
                    .unwrap()
                    .join("../..")
                    .join(format!("toolchains/llvm/prebuilt/{}/lib64/clang", host));

            let sub_dir = std::fs::read_dir(llvm_lib_dir)
                .unwrap()
                .next()
                .unwrap()
                .unwrap()
                .path();

            let ndk_lib_path = sub_dir
                .join("lib/linux")
                .into_os_string()
                .into_string()
                .unwrap();

            println!("cargo:rustc-link-search={}", ndk_lib_path);
            println!(
                "cargo:rustc-link-lib=static=clang_rt.builtins-{}-android",
                target
            );
        }
        _ => {}
    };
}
