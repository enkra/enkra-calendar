# Enkra Calendar

Enkra Calendar is a privacy-focused calendar app that keeps your dates and events secure with local encryption and end-to-end encrypted cloud storage (to be implemented in the future). With Enkra Calendar, you can easily schedule your tasks, plans, and meetings in the calendar tab, and use the inbox tab as a draft box for your life and work plans.

## Features

- Calendar tab: schedule your tasks, plans, and meetings in this tab.
- Inbox tab: use this tab as a draft box for your life and work plans. Long press on an item in the inbox to schedule it as a task in the calendar.

## Installation

Download it from the <a href='https://play.google.com/store/apps/details?id=io.enkra.calendar' target="_blank">Google Play Store</a>.

<a href='https://play.google.com/store/apps/details?id=io.enkra.calendar' target="_blank"><img src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' alt='Get it on Google Play' height='60' /></a>

Download it from the <a href='https://apps.apple.com/app/apple-store/id6463155534?pt=126502564&ct=github&mt=8' target="_blank">Apple App Store</a>.

<a href='https://apps.apple.com/app/apple-store/id6463155534?pt=126502564&ct=github&mt=8' target="_blank"><img src='https://developer.apple.com/app-store/marketing/guidelines/images/badge-example-preferred_2x.png' alt='Get it on Apple Store' height='45' /></a>

## End to end encryption

Enkra Calendar use [tink-rust](https://github.com/project-oak/tink-rust) to implement a secure local storage and E2EE feature. The cipher code is implemented entirely in Rust, a memory-safe language, to ensure that the implementation is secure and free from common memory-related vulnerabilities.

For auditor reviewing code, here are some specific files that you can focus on:

- All the cipher code located in `native/src/`

## Getting Started with Development

If you would like to contribute to the development of Enkra Send, follow these steps:

### Linux

1. Install the Flutter SDK according to the Flutter documentation.
2. Install the Rust according to the Rust langugage documentation.
3. Install `cargo-make` and `cargo-ndk`

```sh
cargo install cargo-make cargo-ndk
```

4. Install rust android target

```sh
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
```

5. generate dart files

```sh
dart run flutter_oss_licenses:generate.dart
dart run build_runner build
```

6. flutter run or build

```
flutter run
```

or

```
flutter build apk
```

### macOS

1. Install the Flutter SDK according to the Flutter documentation.
2. Install the Rust according to the Rust langugage documentation.
3. Install `cargo-make` and `cargo-ndk`

```sh
cargo install cargo-make cargo-ndk
```

4. Install rust android target

```sh
rustup target add aarch64-apple-ios x86_64-apple-ios
```

5. generate dart files

```sh
dart run flutter_oss_licenses:generate
dart run build_runner build
```

6. build ios

```sh
cargo make -p release ios
```

7. flutter run or build

```
flutter run
```

or

```
flutter build ipa
```

## License

Enkra Calendar is released under the [BSL 1.1](./LICENSE). The software is free to use for non-commercial purposes. After the change date, the software will be released under the GNU General Public License Version 2 ("GPLv2").
