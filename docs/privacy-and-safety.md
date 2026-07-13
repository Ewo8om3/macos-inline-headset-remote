# Privacy and safety

This toolkit is local, inspectable configuration tooling. It does not record audio or process speech.

## Data the project does not collect

The repository code does not:

- access the microphone;
- capture or store audio;
- read Wispr Flow transcripts or account data;
- send analytics or telemetry;
- make network requests during normal CLI operation;
- install its own login item, daemon, Driver Extension, or privileged helper.

Wispr Flow owns its own capture and transcription behavior. Review Wispr Flow's privacy terms separately if you use that preset.

## Files the CLI reads

Depending on the command, the CLI reads:

- device definitions and presets in this checkout;
- Karabiner's connected-device and service status through its local CLI;
- `~/.config/karabiner/karabiner.json`;
- toolkit-created backup metadata and snapshots.

`doctor` may check whether a preset's declared application is running. It does not inspect that application's content.

## Files the CLI writes

Only mutating commands write configuration:

- `install` merges the selected preset into the selected Karabiner profile;
- `uninstall` removes toolkit-owned changes;
- `restore` replaces the current Karabiner configuration with a validated backup.

These commands create or use timestamped backups. A full Karabiner configuration can contain custom rules, device identifiers, application bundle identifiers, and machine-specific preferences. Keep backups private and inspect them before sharing bug reports.

Managed state and backups are stored with private permissions under `~/.local/state/macos-inline-headset-remote/` by default, or `$XDG_STATE_HOME/macos-inline-headset-remote/` when configured. The CLI refuses symlinked state directories and symlinked live Karabiner configuration files.

`--dry-run` performs validation and preview without modifying the live Karabiner configuration.

## Why Karabiner needs permissions

Karabiner-Elements receives physical input events and publishes transformed events through a virtual keyboard. macOS therefore requires permissions and components including background services, Accessibility, and a Driver Extension. Karabiner-Elements 15.9 or earlier may also require Input Monitoring.

Those permissions belong to Karabiner-Elements, not to this repository. Review the [official required macOS settings](https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/) and Karabiner's own privacy documentation before enabling them.

## Keystroke risk

Preset outputs are real keystrokes delivered to the foreground application. In the flagship preset:

- the center button sends `Control+Option+Space`;
- `+` sends `Command+Tab`;
- `−` sends Enter.

Enter may submit a message, accept a dialog, activate a button, or insert a newline depending on focus. Test new presets in a harmless text field, not in a terminal, password prompt, financial form, production console, or destructive dialog.

## Generic-device collision risk

A device condition with vendor/product ID `0/0` is not unique. Explicitly passing `--allow-generic-match` acknowledges that limitation; it cannot prevent a second matching device from triggering the same rule.

Avoid high-impact actions—shell commands, deletion shortcuts, credential submission, purchases, or automation with external side effects—on a generic match. Prefer reversible navigation, dictation toggles, and text-entry actions, and keep the target device set controlled.

## Safe operating practices

- Run `detect` after changing the headset, adapter, dock, or input peripherals.
- Use `--dry-run` before every first install, uninstall, or restore.
- Keep unrelated generic consumer devices disconnected if using a `0/0` definition.
- Run `doctor` after macOS or Karabiner updates.
- Keep a separate copy of the current configuration before `restore --force`.
- Inspect presets from untrusted forks before installing them.
- Never add secret values or account data to presets, test fixtures, or issue reports.

## Removing access

`bin/headset-remote uninstall` removes toolkit-owned mappings, but Karabiner remains installed. Use Karabiner-Elements' built-in uninstaller if you want to remove its background services and Driver Extension, then review System Settings to confirm its permissions are gone.
