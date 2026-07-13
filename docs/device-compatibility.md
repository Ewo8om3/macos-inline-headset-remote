# Device compatibility

Compatibility depends on the input events macOS exposes, not on the logo printed on the headphones.

## Known working shape

The flagship setup was tested with a Bose three-button wired inline remote. Through the tested analog audio connection, macOS and Karabiner report approximately:

```text
Product: Headset
Manufacturer: Apple
Transport: Audio
Vendor ID: 0
Product ID: 0
Consumer device: true
Events: volume_increment, play_or_pause, volume_decrement
```

Other Apple-compatible CTIA three-button remotes may expose the same events and work with the bundled definition. Brand or connector shape alone is not proof.

## The exact `0/0` risk

Vendor ID `0` and product ID `0` are missing or generic identifiers, not a Bose identifier and not a wildcard invented by this project. Two unrelated consumer devices can both report `0/0`.

A Karabiner condition such as:

```json
{
  "vendor_id": 0,
  "product_id": 0,
  "is_consumer": true
}
```

matches every event source satisfying all three fields. It cannot distinguish two simultaneously connected `0/0` consumer devices by product display name or manufacturer text because those strings are not part of the condition.

Consequences can include:

- another remote's volume button emitting Enter;
- a media button unexpectedly toggling dictation;
- the intended headset not being the device that was tested;
- broader interception after adding a new adapter or peripheral.

The CLI therefore requires `--allow-generic-match` for such a definition. That flag records informed intent; it does not reduce the collision surface.

## Safely evaluate a device

1. Disconnect other headsets, USB audio adapters, media controllers, and consumer-button peripherals.
2. Connect only the target headset through the adapter you plan to keep using.
3. Run `bin/headset-remote detect`.
4. Open Karabiner-EventViewer and use its **Devices** tab to compare identifiers.
5. Temporarily test the three buttons in EventViewer.
6. Reconnect other peripherals one at a time and rerun detection.
7. Preview the preset installation before applying it.

If two connected consumer devices share the same match, do not rely on that condition for safety-critical keystrokes. Prefer a device or adapter that exposes stable nonzero identifiers, or use a more specific definition supported by Karabiner.

## Adapters matter

USB-C, Lightning, 3.5 mm, docks, and audio interfaces can translate or suppress inline-button events. Changing the adapter may change:

- whether the buttons appear at all;
- the product and manufacturer labels;
- vendor and product IDs;
- event names;
- whether the device is classified as consumer input.

Treat a new adapter as a new compatibility test.

## Common compatibility outcomes

| Observation | Meaning | Next step |
| --- | --- | --- |
| All three expected consumer events appear | Likely compatible | Preview the preset |
| Audio works, but no button events appear | Adapter or headset controls are not exposed as HID input | Try a different adapter/connection |
| Only play/pause appears | Partial remote support | Create a reduced preset; do not assume volume events |
| Stable nonzero IDs appear | Better device scope is possible | Add a specific device definition |
| Several devices report consumer `0/0` | Collision risk | Disconnect conflicts or avoid the generic rule |

## Reporting compatibility

When opening an issue or pull request, include sanitized output from `detect`, the macOS and Karabiner versions, headset model, adapter model, and the three raw EventViewer event names. Do not attach your complete `karabiner.json`; it may contain unrelated personal configuration.
