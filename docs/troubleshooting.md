# Troubleshooting

Start with:

```zsh
bin/headset-remote detect
bin/headset-remote doctor --preset wispr-flow
```

Keep the full output for diagnosis, but remove usernames or personal paths before posting it publicly.

## `jq` is missing

Install it with Homebrew:

```zsh
brew install jq
```

Then confirm:

```zsh
jq --version
```

## Karabiner-Elements is missing or too old

Install Karabiner-Elements 15.4 or newer from its [official site](https://karabiner-elements.pqrs.org/), open it once, and complete setup. The minimum exists because the device scope uses consumer-device identifiers supported by modern Karabiner versions.

## Driver or virtual keyboard is not ready

Open Karabiner-Elements Settings and follow the displayed setup guidance. Check:

- background services are enabled in **System Settings → General → Login Items**;
- Karabiner is allowed under **Privacy & Security → Accessibility**;
- the Karabiner Driver Extension is allowed under **Login Items & Extensions → Driver Extensions**;
- Input Monitoring is allowed if you run Karabiner-Elements 15.9 or earlier.

Restart Karabiner and rerun `doctor`. After a macOS update, a Mac restart may be necessary. See Karabiner's [required macOS settings](https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/).

## No headset is detected

1. Confirm audio works through the same connection.
2. Reconnect the headset and adapter.
3. Run `detect` again.
4. Open Karabiner-EventViewer → **Devices** and look for a consumer device.
5. Press each inline button in EventViewer.
6. Try a different Apple-compatible adapter.

Some adapters carry audio but do not translate inline-button controls into HID consumer events.

## More than one generic device matches

The refusal is intentional. Vendor/product ID `0/0` does not uniquely identify the headset.

Disconnect unrelated headsets, audio adapters, docks, presentation remotes, and media-control devices, then rerun `detect`. If one verified target remains, preview the install with `--allow-generic-match`.

If multiple `0/0` consumer devices must stay connected, avoid the generic rule or use hardware that exposes distinct identifiers. The override cannot choose one of two identical Karabiner conditions.

## The headset is disconnected during installation

Connect it and rerun the command. If offline installation is intentional and you previously verified the exact definition, use:

```zsh
bin/headset-remote install \
  --preset wispr-flow \
  --allow-generic-match \
  --allow-disconnected
```

`--allow-disconnected` skips connection proof. It does not imply `--allow-generic-match` and does not validate the current adapter.

## Buttons still change volume

- Run `doctor --preset wispr-flow`.
- In Karabiner-Elements Settings → **Devices**, confirm modification is enabled for the headset consumer device.
- In **Complex Modifications**, confirm the expected rule is enabled in the selected profile.
- Use EventViewer to confirm the physical events are `volume_increment`, `play_or_pause`, and `volume_decrement`.
- Check Karabiner's log for JSON or service errors.

If the events come from a different device definition, the rule will not match.

## The center button does nothing

1. Confirm Wispr Flow is installed and running.
2. Open Wispr Flow settings and check its hands-free shortcut.
3. Confirm it is `Control+Option+Space`, or update/create a preset to emit the configured shortcut.
4. Test the shortcut on the keyboard to separate a Wispr issue from a remote-mapping issue.
5. Use EventViewer to confirm the remote emits `play_or_pause`.

## `+` only switches to the previous app

A quick press sends one `Command+Tab`, which switches to the previous app. Hold `+` so the repeating input advances through the application switcher, then release on the desired app.

If holding does not repeat, inspect the raw event stream in EventViewer and compare it with a keyboard `Command+Tab` test.

## `−` inserts a newline instead of sending

The preset emits Enter. The foreground application decides whether Enter sends, activates a control, or inserts a newline. Enable that application's Enter-to-send preference if it has one.

Do not replace Enter with a destructive or application-specific shortcut in a generic `0/0` preset without carefully scoping and testing it.

## The wrong device triggers the mapping

Immediately disable the rule in Karabiner-Elements → **Complex Modifications**, or run:

```zsh
bin/headset-remote uninstall
```

Then inspect all connected devices. This is the expected failure mode of a generic `0/0` collision. An allow flag cannot make those identifiers unique.

## The Karabiner configuration is malformed

The CLI refuses to replace malformed input because it cannot prove a safe merge. Use Karabiner's log or `jq` to locate the syntax problem:

```zsh
jq empty ~/.config/karabiner/karabiner.json
```

If the malformed file resulted from a recent toolkit operation, inspect available backups:

```zsh
bin/headset-remote backups
bin/headset-remote restore --latest --dry-run
```

Do not use `--force` until you have copied the current file and inspected the backup.

## A restore is refused

The live configuration has likely diverged since the backup was created. This may be a legitimate newer Karabiner change.

1. Copy the current `karabiner.json` to a safe location.
2. Run `backups` and inspect timestamps.
3. Run `restore --latest --dry-run`.
4. Prefer a targeted `uninstall` or manual merge if newer changes must be preserved.
5. Add `--force` only when replacing the entire current state is intentional; every non-dry-run full restore requires that explicit acknowledgment.

## Collecting a useful bug report

Include:

- the command you ran and complete sanitized output;
- macOS and Karabiner versions;
- headset and adapter models;
- sanitized `detect` output;
- the three raw EventViewer events;
- whether the issue reproduces after a dry run and `doctor`.

Do not post your full Karabiner configuration, backup files, account details, transcripts, or secrets.

## An operation lock or interrupted-operation message appears

The CLI serializes configuration writes under its private state directory. If the recorded lock owner process is still running, wait for that command to finish. A valid lock left by a process that no longer exists is removed automatically on the next mutating command.

Do not manually delete a live lock. If the CLI reports an unverified lock or says the current configuration matches neither side of a pending journal, preserve the state directory and Karabiner configuration before changing anything. Inspect `bin/headset-remote backups`; the refusal means automatic recovery could not prove which version is authoritative.
