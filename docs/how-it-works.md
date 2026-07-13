# How it works

The project separates hardware identity, desired behavior, and safe configuration mutation.

```text
inline remote
    │ consumer HID events
    ▼
Karabiner-Elements ── device condition + preset mapping ──► virtual keystrokes
    ▲                                                        │
    │ merged configuration                                  ▼
headset-remote CLI                                      foreground app
```

## Device definitions

A device definition describes how a class of headset remote appears to Karabiner. The tested analog Bose remote is exposed by macOS as a consumer device named `Headset`, manufactured by Apple, transported over `Audio`, with vendor ID `0` and product ID `0`.

Display metadata helps a person confirm what `detect` found. Karabiner's `device_if` condition does the actual event scoping. Karabiner joins multiple fields in one identifier with logical AND.

The `is_consumer` condition is important: it distinguishes consumer-control events from ordinary keyboard or pointing input. It does not make `0/0` unique.

## Presets

A preset describes intent: its stable ID, human-readable metadata, target device definition, button-to-keystroke mappings, and optional application expectations.

The CLI resolves a preset against its device definition and produces a standard Karabiner complex-modification rule. That keeps hardware matching out of the behavior mapping and lets multiple workflows reuse one device definition.

The Wispr Flow preset turns the three consumer events into:

- `volume_increment` → `Command+Tab`;
- `play_or_pause` → `Control+Option+Space`;
- `volume_decrement` → `Return/Enter`.

## Configuration ownership

Karabiner watches `~/.config/karabiner/karabiner.json` and reloads it when it changes. The CLI edits only the selected profile and identifies its own installed rule by a stable project-owned marker.

That enables four properties:

- **Idempotence:** installing a preset twice updates the owned rule instead of duplicating it.
- **Preservation:** unrelated profiles, rules, device settings, and parameters stay intact.
- **Targeted removal:** `uninstall` removes toolkit-owned changes without guessing about user rules.
- **Verification:** `doctor` can distinguish the expected preset from a similarly named manual rule.

## Mutation sequence

An installation follows a guarded sequence:

1. Validate dependencies, arguments, manifests, and the live Karabiner JSON.
2. Resolve the selected preset and device definition.
3. Check connected-device evidence unless explicitly overridden.
4. Refuse a generic `0/0` match without explicit acknowledgment.
5. Build the proposed configuration in a temporary file.
6. Validate the complete proposed JSON.
7. Show the proposal and stop for `--dry-run`, or create a timestamped backup.
8. Write a private recovery journal describing both expected configuration hashes.
9. Recheck that the source configuration has not changed during the operation.
10. Atomically replace the live configuration, record ownership state, and clear the journal.

Karabiner then applies the rule. No daemon from this repository remains running.

The ownership record stores the exact profile, original rule/device entries, and last-applied entries. Later uninstall operations compare current values with that record and refuse to clobber user edits.

Mutating commands also use a PID-owned lock. A live owner blocks concurrent writes; a valid lock whose process no longer exists is recovered automatically. If a process stops between configuration and state updates, the next mutating command uses the journal and backup to finish bookkeeping or roll back safely.

## Backups and restore guards

Backups are complete configuration snapshots because a partial fragment is not sufficient to recreate all selected-profile state. A restore therefore has the power to overwrite unrelated changes made after the backup.

The restore preview validates the chosen backup and shows the replacement without writing. Every actual full restore requires `--force`, an explicit acknowledgment that newer unrelated Karabiner changes may be overwritten.

## Why Karabiner-Elements

Karabiner already provides mature macOS event capture, device conditions, a virtual keyboard driver, an EventViewer, and configuration reloads. Reusing it keeps this project inspectable and avoids introducing another privileged background application.

Relevant Karabiner documentation:

- [Complex modifications](https://karabiner-elements.pqrs.org/docs/manual/configuration/configure-complex-modifications/)
- [`device_if` conditions](https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/conditions/device/)
- [Configuration file locations](https://karabiner-elements.pqrs.org/docs/json/location/)
