# CLI reference

Run all commands from the repository root:

```zsh
bin/headset-remote <command> [options]
```

The CLI exits nonzero for invalid arguments, failed safety checks, invalid JSON, or an unhealthy requested state. Read the accompanying message before overriding a safeguard.

## `detect`

```zsh
bin/headset-remote detect [--preset ID]
```

Lists connected input devices relevant to the selected preset's device definition. `--preset ID` selects a preset; when omitted, detection defaults to `wispr-flow`. Use it before installation and whenever an adapter or connection path changes.

Examples:

```zsh
bin/headset-remote detect
bin/headset-remote detect --preset f18-dictation
```

Pay particular attention to generic devices with vendor ID `0` and product ID `0`. Those identifiers can describe more than one physical device.

## `list-presets`

```zsh
bin/headset-remote list-presets
```

Lists installed preset IDs and their descriptions. Pass the stable ID—not a display name—to `install` and `doctor`.

## `install`

```zsh
bin/headset-remote install --preset ID [--profile NAME] [--dry-run]
  --allow-generic-match [--allow-disconnected] [--migrate-legacy]
```

Safely merges a preset into the selected Karabiner profile.

Options:

- `--preset ID` selects the preset and is required.
- `--profile NAME` targets one exact Karabiner profile instead of the currently selected profile.
- `--dry-run` validates and shows the planned operation without writing files.
- `--allow-generic-match` acknowledges that a `0/0` device condition is non-unique. It does not narrow the match.
- `--allow-disconnected` permits installation when the preset's device is not currently detected. Use it only after identifying the device while connected.
- `--migrate-legacy` removes only the exact legacy rule descriptions declared by the selected preset. Inspect a dry run first; this is intended for upgrades from an earlier release of this project.

Without `--dry-run`, the command creates a timestamped backup before changing the active configuration. Reinstalling the same preset replaces the toolkit-owned rule instead of creating a duplicate.

For a generic wired headset:

```zsh
bin/headset-remote install --preset wispr-flow --dry-run --allow-generic-match
bin/headset-remote install --preset wispr-flow --allow-generic-match
```

## `doctor`

```zsh
bin/headset-remote doctor [--preset ID] [--profile NAME]
```

Checks the installation and reports actionable failures. With `--preset`, it also validates that preset's expected rule and device state. When managed state exists for that preset, `doctor` checks the profile recorded during installation—even when it is not currently selected. Pass `--profile NAME` to check one exact profile explicitly; otherwise the selected profile is used.

Typical checks include:

- required commands and supported Karabiner version;
- live Karabiner configuration syntax;
- resolved profile and installed owned rule;
- Karabiner services, Driver Extension, and virtual keyboard readiness where available;
- connected device state;
- preset-specific application state where declared.

Use the command's exit status in local diagnostics or CI-like scripts:

```zsh
if bin/headset-remote doctor --preset wispr-flow; then
  print 'Headset remote is ready'
fi
```

## `uninstall`

```zsh
bin/headset-remote uninstall [--dry-run]
```

Removes only changes owned by this toolkit from the profile recorded during installation. It does not uninstall Karabiner-Elements or delete unrelated rules. If the managed rule or device entry has been edited since installation, uninstall refuses to overwrite that newer work.

Preview first:

```zsh
bin/headset-remote uninstall --dry-run
bin/headset-remote uninstall
```

## `backups`

```zsh
bin/headset-remote backups
```

Lists configuration backups created by mutating CLI operations. Backups can contain your complete Karabiner configuration, including unrelated custom rules, so treat them as private configuration data.

Managed state and mode-`600` backups live under `~/.local/state/macos-inline-headset-remote/` by default, or `$XDG_STATE_HOME/macos-inline-headset-remote/` when `XDG_STATE_HOME` is set.

## `restore`

```zsh
bin/headset-remote restore (--latest | --backup PATH) [--dry-run] [--force]
```

Restores the newest toolkit backup.

- `--latest` selects the most recent available backup.
- `--backup PATH` selects a specific backup shown by `backups`.
- `--dry-run` validates and previews without replacing the active configuration.
- `--force` is required for the actual restore because a backup replaces the complete Karabiner configuration, not only this project's rule. It can overwrite newer unrelated changes.

Recommended sequence:

```zsh
bin/headset-remote backups
bin/headset-remote restore --latest --dry-run
bin/headset-remote restore --latest --force
bin/headset-remote doctor
```

Before using `--force`, copy `~/.config/karabiner/karabiner.json` somewhere safe and inspect the restore preview. To choose an older snapshot, use `restore --backup PATH --dry-run`, followed by the same command with `--force`.
