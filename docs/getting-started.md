# Getting started

This guide installs the included Wispr Flow mapping without replacing unrelated Karabiner-Elements settings.

## 1. Install the requirements

You need:

- macOS;
- Karabiner-Elements 15.4 or newer;
- Zsh, included with macOS;
- `jq`;
- a compatible wired inline remote.

Install `jq` with Homebrew:

```zsh
brew install jq
```

Download and install [Karabiner-Elements](https://karabiner-elements.pqrs.org/), open its settings once, and follow every setup prompt. macOS must allow Karabiner's background services, Accessibility access, and Driver Extension. Karabiner-Elements 15.9 or earlier may also require Input Monitoring.

## 2. Connect and inspect the headset

Connect the headset directly or through the adapter you intend to use every day. Then run:

```zsh
bin/headset-remote detect
```

The tool reports compatible consumer devices and the identifiers Karabiner sees. Compare:

- product and manufacturer;
- transport;
- vendor and product IDs;
- whether the device exposes consumer controls;
- whether more than one candidate matches.

The tested Bose headset appears as an Apple `Headset` over `Audio`, with consumer events and vendor/product ID `0/0`.

> [!CAUTION]
> `0/0` means macOS did not expose useful vendor and product identifiers. It does not mean “Bose,” and it is not a unique hardware identity. Another generic consumer device may match the same condition. Disconnect unrelated headsets, dongles, and button devices while identifying yours.

If no device appears, continue with [Device compatibility](device-compatibility.md) and [Troubleshooting](troubleshooting.md).

## 3. Inspect the preset

List the included presets:

```zsh
bin/headset-remote list-presets
```

The `wispr-flow` preset maps:

| Remote event | Output |
| --- | --- |
| `volume_increment` | `Command+Tab` |
| `play_or_pause` | `Control+Option+Space` |
| `volume_decrement` | `Return/Enter` |

The center-button shortcut assumes Wispr Flow's hands-free shortcut is `Control+Option+Space`. If your Wispr Flow settings differ, change the shortcut or create a local preset before installing.

## 4. Preview the change

For a generic `0/0` headset, preview with the required acknowledgment:

```zsh
bin/headset-remote install --preset wispr-flow --dry-run --allow-generic-match
```

The preview should identify the selected Karabiner profile, the rule that will be added or replaced, and the device entry that will be enabled. A dry run does not write the configuration or create a backup.

If the headset is intentionally disconnected, add `--allow-disconnected`. This skips connection proof; it does not make a generic match safer.

## 5. Install and verify

With the headset still connected:

```zsh
bin/headset-remote install --preset wispr-flow --allow-generic-match
bin/headset-remote doctor --preset wispr-flow
```

The installer:

1. validates the preset and current Karabiner JSON;
2. confirms that the target device is connected unless you used `--allow-disconnected`;
3. requires explicit opt-in for a generic `0/0` match;
4. saves a timestamped backup;
5. merges the owned rule into the selected profile;
6. preserves unrelated profiles, devices, and complex modifications;
7. validates the result before replacing the live file.

Running the same install again updates the owned rule instead of duplicating it.

## 6. Try the buttons

Open a text field where an accidental Enter press is harmless.

1. Press the center button once to begin Wispr Flow hands-free capture.
2. Press it again to stop.
3. Hold `+` to open and move through the macOS application switcher; release to select.
4. Press `−` and confirm that it emits Enter.

The headset buttons no longer control media volume while this rule is active. Keyboard media keys are unaffected when the rule is correctly scoped to the headset device.

## Next steps

- Keep [CLI reference](cli-reference.md) nearby for backup and restore commands.
- Read [Privacy and safety](privacy-and-safety.md) before broadening a device condition.
- Use [Creating presets](creating-presets.md) to adapt the mapping to another dictation application.
