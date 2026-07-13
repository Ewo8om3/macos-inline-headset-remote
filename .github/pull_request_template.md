## What changed

Describe the user problem and the chosen behavior.

## Safety

- [ ] Generic identifier behavior is explicit and still requires acknowledgment.
- [ ] Unrelated Karabiner profiles, rules, devices, and parameters are preserved.
- [ ] No personal configurations, backups, transcripts, credentials, or secrets are included.
- [ ] New preset actions are reversible and contain no `shell_command` entries.

## Verification

- [ ] `zsh -n bin/headset-remote tests/*.zsh`
- [ ] `tests/validate-rules.zsh`
- [ ] `tests/run.zsh`

List live hardware testing and anything not tested.
