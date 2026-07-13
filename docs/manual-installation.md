# Manual installation

Manual import is useful when you want to inspect and enable a Karabiner rule yourself. It gives up the CLI's device-detection gate, safe merge, ownership tracking, backup catalog, targeted uninstall, and restore workflow.

## Before importing

1. Run `bin/headset-remote detect` or inspect the headset in Karabiner-EventViewer.
2. Open the preset's Karabiner JSON and read every output keystroke.
3. Read every `device_if` condition.
4. If it contains vendor/product ID `0/0`, review [Device compatibility](device-compatibility.md) and disconnect any conflicting generic consumer devices.
5. Back up `~/.config/karabiner/karabiner.json`.

## Import a local complex modification

Karabiner loads local predefined rules from:

```text
~/.config/karabiner/assets/complex_modifications/
```

Copy the complete complex-modification JSON for the preset into that directory. For example:

```zsh
mkdir -p ~/.config/karabiner/assets/complex_modifications
cp presets/wispr-flow/karabiner.json \
  ~/.config/karabiner/assets/complex_modifications/inline-headset-remote-wispr-flow.json
```

Then:

1. Open Karabiner-Elements Settings.
2. Select **Complex Modifications**.
3. Choose **Add predefined rule**.
4. Find the imported rule.
5. Choose **Enable**.
6. Open Karabiner-EventViewer and test each inline button.

Karabiner documents this UI in [Use more complex modifications](https://karabiner-elements.pqrs.org/docs/manual/configuration/configure-complex-modifications/). Its [file locations reference](https://karabiner-elements.pqrs.org/docs/json/location/) describes the local assets directory.

## Enable the device

Open Karabiner-Elements Settings → **Devices** and confirm that event modification is enabled for the headset consumer device. If several generic `0/0` devices appear, the UI label may help you understand the current connection, but the JSON `0/0` condition still cannot uniquely distinguish them.

## Disable or remove the rule

In Karabiner-Elements Settings → **Complex Modifications**, disable or remove the exact rule you enabled. Delete the copied asset JSON only after removing the enabled rule.

Manual rules are not automatically treated as toolkit-owned changes. Do not expect `bin/headset-remote uninstall` to remove a hand-edited rule unless its ownership metadata exactly matches what the CLI installs.

## Prefer the CLI when

Use the CLI instead if you want:

- a no-write preview;
- refusal of unacknowledged generic matches;
- connected-device validation;
- preservation checks and atomic replacement;
- timestamped backups and guarded restore;
- repeatable installation and diagnosis.
