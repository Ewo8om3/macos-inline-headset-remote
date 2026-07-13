# macOS Inline Headset Remote

Turn an Apple-compatible three-button wired headset remote into a programmable macOS controller.

The included Wispr Flow preset maps:

| Inline button | Action |
| --- | --- |
| `+` | Hold to cycle through applications with `Command+Tab`; release to select |
| Center / play | Toggle Wispr Flow hands-free capture with `Control+Option+Space` |
| `−` | Press `Return/Enter` to send in applications where Enter sends |

Tested with a Bose wired headset and Wispr Flow. The toolkit also supports custom Karabiner-Elements presets for other three-button remotes and workflows.

`Control+Option+Space` is the shortcut used by this preset, not a universal Wispr Flow default. Configure it under **Flow Hub → Settings → General → Shortcuts → Hands-free** before testing. Wispr documents how to [change the hands-free shortcut](https://docs.wisprflow.ai/articles/6391241694-use-flow-hands-free).

Included presets:

- `wispr-flow` — `+` switches apps, center toggles Wispr Flow hands-free capture, and `−` sends Enter.
- `f18-dictation` — the same navigation controls with center emitting `F18`; bind `F18` in the target dictation application.
- `modifier-push-to-talk` — the same navigation controls with center held as `Control+Option`; bind that chord as push-to-talk in the target application.

> [!WARNING]
> Many analog inline remotes appear to macOS as a generic consumer device with vendor ID `0` and product ID `0`. Those identifiers are not unique. A rule that matches `0/0` can capture buttons from another connected generic consumer device. This project refuses a generic match unless you inspect it and explicitly pass `--allow-generic-match`.

## Requirements

- macOS
- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) 15.4 or newer
- Zsh
- [`jq`](https://jqlang.github.io/jq/)
- An Apple-compatible wired headset whose inline buttons emit consumer events

Wispr Flow is required only for the included `wispr-flow` preset.

## Tested environment

The v1.0.1 workflow was verified with this exact setup:

| Component | Tested value |
| --- | --- |
| Mac | Mac Studio (`Mac16,9`) with Apple M4 Max |
| macOS | 26.5.2 (build `25F84`) |
| Karabiner-Elements | 16.1.0 |
| Wispr Flow | 1.6.7 |
| Headset | Bose three-button wired headset; the exact model is not exposed to macOS |
| Connection | Mac Studio built-in 3.5 mm headphone jack; no adapter |
| Detected input | Apple `Headset` over `Audio`, exposed as a generic vendor/product `0/0` consumer device |

Other Apple-compatible inline remotes may work, but this table is evidence for the tested path rather than a general compatibility claim. See [Device compatibility](docs/device-compatibility.md) before relying on a different headset or connection.

Install `jq` with Homebrew if needed:

```zsh
brew install jq
```

Open Karabiner-Elements once and complete its macOS permission setup before using the installer. Karabiner requires its background services, Accessibility access, and Driver Extension; versions through 15.9 may also request Input Monitoring. See the [official installation guide](https://karabiner-elements.pqrs.org/docs/getting-started/installation/).

## Quick start

Clone the repository, then run the CLI from the checkout:

```zsh
git clone --branch v1.0.1 --depth 1 \
  https://github.com/Ewo8om3/macos-inline-headset-remote.git
cd macos-inline-headset-remote
bin/headset-remote detect
bin/headset-remote list-presets
```

`detect` defaults to the `wispr-flow` preset; use `detect --preset ID` when evaluating another preset. Read the detection output carefully. If it reports a generic `0/0` device and the listed product, manufacturer, transport, and consumer-device type match your headset, preview the installation:

```zsh
bin/headset-remote install --preset wispr-flow --dry-run --allow-generic-match
```

Apply it, then verify the complete setup:

```zsh
bin/headset-remote install --preset wispr-flow --allow-generic-match
bin/headset-remote doctor --preset wispr-flow
```

The installer changes only the selected Karabiner profile, preserves unrelated rules, creates a timestamped backup before writing, and does not create duplicate rules when run again.

Use `--allow-disconnected` only when you intentionally need to install a preset while its declared device is not connected:

```zsh
bin/headset-remote install \
  --preset wispr-flow \
  --allow-generic-match \
  --allow-disconnected
```

## Undo or recover

Remove only the rule installed by this toolkit:

```zsh
bin/headset-remote uninstall --dry-run
bin/headset-remote uninstall
```

List the backups recorded by the toolkit and preview restoring the newest one:

```zsh
bin/headset-remote backups
bin/headset-remote restore --latest --dry-run
bin/headset-remote restore --latest --force
```

A full restore intentionally requires `--force` because it replaces the entire Karabiner configuration, including unrelated rules. Inspect the dry-run output and keep a separate copy of the current configuration before using it. You can restore a specific listed backup with `--backup PATH` instead of `--latest`.

## Manual Karabiner import

If you prefer not to let the CLI edit `~/.config/karabiner/karabiner.json`:

1. Copy the preset's `karabiner.json` into `~/.config/karabiner/assets/complex_modifications/`.
2. Open Karabiner-Elements Settings.
3. Choose **Complex Modifications** → **Add predefined rule**.
4. Find the imported rule and choose **Enable**.
5. Use Karabiner-EventViewer to confirm the result.

This path enables a rule but does not provide the CLI's detection gate, ownership tracking, backups, idempotent merge, diagnostics, or targeted uninstall. Inspect every `device_if` condition first—especially any `vendor_id: 0` / `product_id: 0` match. See [Manual installation](docs/manual-installation.md) for the exact workflow.

## What it changes

Karabiner receives hardware consumer events such as `volume_increment`, `play_or_pause`, and `volume_decrement`, then emits the keystrokes declared by a preset. Device conditions scope those transformations to the selected headset.

This project:

- does not record audio;
- does not access transcripts, Wispr Flow data, or accounts;
- does not run a background service of its own;
- does not send telemetry or make network requests;
- does edit the selected profile in `~/.config/karabiner/karabiner.json` when you run `install`, `uninstall`, or `restore` without `--dry-run`.

Karabiner-Elements remains the resident input engine and requires macOS input-related permissions. See [Privacy and safety](docs/privacy-and-safety.md).

## Documentation

- [Getting started](docs/getting-started.md)
- [CLI reference](docs/cli-reference.md)
- [How it works](docs/how-it-works.md)
- [Device compatibility](docs/device-compatibility.md)
- [Manual installation](docs/manual-installation.md)
- [Creating presets](docs/creating-presets.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Privacy and safety](docs/privacy-and-safety.md)

## Project status

The project is intentionally small: a Zsh CLI, declarative device and preset files, and Karabiner-Elements as the proven input engine. See [CHANGELOG.md](CHANGELOG.md) for release history.

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), particularly the safety requirements for new device definitions and presets.

## License and trademarks

Released under the [MIT License](LICENSE).

This is an independent, unofficial project. It is not affiliated with or endorsed by Apple, Bose, Wispr Flow, or Karabiner-Elements. Product names and trademarks belong to their respective owners.
