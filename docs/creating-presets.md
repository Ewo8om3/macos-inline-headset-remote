# Creating presets

A preset is a declarative bundle under `presets/<id>/`:

```text
presets/
└── my-dictation/
    ├── manifest.json
    └── karabiner.json
```

The manifest is the CLI-facing metadata and the Karabiner file is a standard importable complex modification. Keep the directory name, manifest `id`, and ownership marker aligned.

## Start from an existing preset

Copy the closest bundled preset:

```zsh
cp -R presets/f18-dictation presets/my-dictation
```

Then edit both JSON files. Do not edit a bundled preset in place for a personal shortcut; a separate ID makes updates and uninstall ownership predictable.

## Manifest format

`manifest.json` uses these fields:

```json
{
  "schema_version": 1,
  "id": "my-dictation",
  "name": "My dictation toggle",
  "summary": "Use the inline remote with My Dictation App.",
  "device_file": "apple-audio-headset.json",
  "rule_file": "karabiner.json",
  "rule_description": "[inline-headset-remote:my-dictation:v1] + apps, center dictation, - send",
  "legacy_descriptions": [],
  "minimum_karabiner_version": "15.4.0",
  "required_process": "My Dictation App",
  "mappings": [
    {
      "button": "+",
      "input": "volume_increment",
      "action": "Command+Tab application switcher"
    },
    {
      "button": "center",
      "input": "play_or_pause",
      "action": "F18 dictation toggle"
    },
    {
      "button": "-",
      "input": "volume_decrement",
      "action": "Return/Enter"
    }
  ]
}
```

Field reference:

| Field | Meaning |
| --- | --- |
| `schema_version` | Manifest schema version. Use integer `1`. |
| `id` | Stable lowercase kebab-case preset ID; must equal the directory name. |
| `name` | Short display name used by `list-presets`. |
| `summary` | One-sentence description of the workflow. |
| `device_file` | Filename of the target definition under `devices/`. |
| `rule_file` | Preset-relative Karabiner rule filename; normally `karabiner.json`. |
| `rule_description` | Exact `.rules[0].description` in the Karabiner file and the stable ownership key. |
| `legacy_descriptions` | Exact old rule descriptions that may be safely replaced during migration. Use `[]` for a new preset. |
| `minimum_karabiner_version` | Minimum tested Karabiner version. Consumer matching requires at least `15.4.0`. |
| `required_process` | macOS process name checked by `doctor`; use an empty string when no application is required. |
| `mappings` | Human-readable button, raw input, and action records shown to users and diagnostics. |

Do not put secrets, home-directory paths, bundle-specific tokens, or shell fragments in a manifest.

## Karabiner rule format

`karabiner.json` must be a complete complex-modification asset with a nonempty `title` and `rules` array:

```json
{
  "title": "Inline Headset Remote — My Dictation",
  "rules": [
    {
      "description": "[inline-headset-remote:my-dictation:v1] + apps, center dictation, - send",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "consumer_key_code": "play_or_pause",
            "modifiers": {
              "optional": ["any"]
            }
          },
          "to": [
            {
              "key_code": "f18"
            }
          ],
          "conditions": [
            {
              "type": "device_if",
              "identifiers": [
                {
                  "vendor_id": 0,
                  "product_id": 0,
                  "is_consumer": true
                }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

Every manipulator must:

- use `type: "basic"`;
- read a nonempty `from.consumer_key_code`;
- emit at least one `to` entry with a valid `key_code`;
- include a `device_if` condition matching the device definition;
- accept optional modifiers when physical consumer events may arrive alongside ambient modifier state.

For the bundled Apple audio headset definition, the condition is exactly:

```json
{
  "vendor_id": 0,
  "product_id": 0,
  "is_consumer": true
}
```

That condition has the collision risk described in [Device compatibility](device-compatibility.md). Do not add product or manufacturer display strings to `identifiers`; Karabiner does not support them as device-condition keys.

## Ownership and migrations

Use this description prefix:

```text
[inline-headset-remote:<preset-id>:v1]
```

The full description must exactly equal `manifest.json`'s `rule_description`. This marker lets repeated installation replace the same rule and lets uninstall avoid unrelated user rules.

When renaming a previously released description, add the complete old string to `legacy_descriptions`. Never add a broad prefix or a description owned by another preset.

Increase the marker version only when migration semantics require a new ownership identity. Ordinary shortcut changes can retain the same stable description and be delivered as an idempotent update.

## Choosing mappings

Use Karabiner-EventViewer to confirm actual input names. Common three-button events are:

- `volume_increment` for `+`;
- `play_or_pause` for center;
- `volume_decrement` for `−`.

Use standard Karabiner key codes such as `tab`, `spacebar`, `return_or_enter`, or `f18`. Modifiers use names such as `left_command`, `left_control`, and `left_option`.

Avoid `shell_command`, destructive shortcuts, credentials, URLs with tokens, and irreversible external side effects. Presets matching generic `0/0` devices should remain low impact.

## Add a device definition only when needed

If your preset targets different hardware, add `devices/<id>.json` with the exact schema:

```json
{
  "schema_version": 1,
  "id": "my-device",
  "name": "My inline remote",
  "description": "How macOS exposes the device.",
  "karabiner_identifiers": {
    "vendor_id": 1234,
    "product_id": 5678,
    "is_consumer": true
  },
  "detection": {
    "product": "Observed Product",
    "transport": "USB",
    "is_consumer": true
  },
  "generic_identifier_warning": false,
  "tested_hardware": [
    {
      "name": "Manufacturer and model",
      "mac": "Tested Mac model",
      "status": "verified"
    }
  ]
}
```

Set `generic_identifier_warning` to `true` whenever the Karabiner identifiers are generic or plausibly collide. Device claims must be based on observed data, not branding assumptions.

## Validate and test

Run:

```zsh
jq empty devices/*.json presets/*/*.json
tests/validate-rules.zsh
tests/run.zsh
bin/headset-remote list-presets
bin/headset-remote install --preset my-dictation --dry-run --allow-generic-match
```

For live hardware testing:

1. Back up the active Karabiner configuration.
2. Disconnect unrelated generic consumer devices.
3. Inspect all three events in EventViewer.
4. Install with a dry run first.
5. Test outputs in a harmless text field.
6. Run `doctor --preset my-dictation`.
7. Install a second time and confirm there is only one owned rule.
8. Uninstall and confirm unrelated configuration remains identical.

Include the tested hardware, adapter, macOS version, Karabiner version, and any untested paths in the pull request.
