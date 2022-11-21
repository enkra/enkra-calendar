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

    let target_arch = std::env::var("TARGET").unwrap();

    if target_arch.contains("android") {
        android::android_build();
    }

    if target_arch.contains("ios") {
        ios::ios_build();
    }
}

mod android {
    use std::path::PathBuf;

    pub fn android_build() {
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
}

mod ios {
    use std::fs::File;
    use std::path::PathBuf;
    use std::process::Command;

    use ar::Builder;

    pub fn ios_build() {
        let out_dir: PathBuf = std::env::var("OUT_DIR").unwrap().into();

        let target_arch = std::env::var("TARGET").unwrap();

        let sdk = find_sdk(&target_arch);

        build_ios_swift(&out_dir, &sdk, &target_arch);

        println!("cargo:rustc-link-search={}", out_dir.to_string_lossy());
        println!("cargo:rustc-link-lib=static=ios");
    }

    fn find_sdk(target_arch: &str) -> String {
        let sdk_name = match target_arch {
            "aarch64-apple-ios" => Some("iphoneos"),
            "x86_64-apple-ios" => Some("iphonesimulator"),
            _ => None,
        }
        .unwrap();

        let sdk = Command::new("xcrun")
            .args(["--sdk", sdk_name, "--show-sdk-path"])
            .output()
            .expect("failed to execute process")
            .stdout;

        let sdk = std::str::from_utf8(&sdk).unwrap().trim();

        sdk.to_string()
    }

    fn build_ios_swift(out_dir: &PathBuf, sdk: &str, target_arch: &str) {
        let swift_target = match target_arch {
            "aarch64-apple-ios" => Some("aarch64-apple-ios14"),
            "x86_64-apple-ios" => Some("x86_64-apple-ios14-simulator"),
            _ => None,
        }
        .unwrap();

        let obj = out_dir.join("ios.o");

        let output = Command::new("swiftc")
            .args([
                "-c",
                "ios-swift/src/lib.swift",
                "-target",
                swift_target,
                "-sdk",
                &sdk,
                "-g",
                "-swift-version",
                "5",
                "-O",
                "-D",
                "SWIFT_PACKAGE",
                "-D",
                "RELEASE",
                "-module-name",
                "ios_swift",
                "-parse-as-library",
                "-o",
                &obj.to_string_lossy(),
            ])
            .output()
            .expect("failed to execute process")
            .stderr;

        println!("{}", String::from_utf8_lossy(&output));

        let mut builder = Builder::new(File::create(out_dir.join("libios.a")).unwrap());

        builder.append_path(obj).unwrap();
    }
}
