# Changelog

All notable changes to this project are documented here. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2026-07-12

### Fixed

- Reject installation before changing the Karabiner configuration when the installed Karabiner-Elements version is below the preset's `minimum_karabiner_version`.
- Let `detect` target a preset with `--preset ID`, defaulting to `wispr-flow` when omitted.
- Print the CLI's actual invocation path in the post-install `doctor` command so checkout-based installs do not suggest an unavailable global command.
- Stop an internal device variable declaration from appearing in repeated-install dry-run output.

### Documentation

- Pin the quick-start checkout to the v1.0.1 release tag.
- Record the exact macOS, Mac, Karabiner-Elements, Wispr Flow, headset, connection, and detected-device setup used for verification.

## [1.0.0] - 2026-07-12

### Added

- Device detection for compatible inline headset remotes.
- Declarative device definitions and behavior presets.
- A Wispr Flow preset for application switching, hands-free capture, and Enter/send.
- Safe, idempotent Karabiner configuration installation with dry-run support.
- Explicit opt-in for generic vendor/product ID `0/0` matches.
- Connected-device validation with an explicit offline installation override.
- Health checks, owned-rule uninstall, timestamped backups, and guarded restore.
- Manual Karabiner import documentation.
- Fixture-based validation and continuous integration checks.

[Unreleased]: https://github.com/Ewo8om3/macos-inline-headset-remote/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/Ewo8om3/macos-inline-headset-remote/releases/tag/v1.0.1
[1.0.0]: https://github.com/Ewo8om3/macos-inline-headset-remote/releases/tag/v1.0.0
