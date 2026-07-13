#!/bin/zsh

source "${0:A:h}/test-helper.zsh"

selected_rules_count() {
  jq '[.profiles[] | select(.selected == true) | .complex_modifications.rules[]] | length' "$HEADSET_REMOTE_CONFIG"
}

selected_devices_count() {
  jq '[.profiles[] | select(.selected == true) | .devices[]] | length' "$HEADSET_REMOTE_CONFIG"
}

fixture_sha256() {
  /usr/bin/shasum -a 256 -- "$1" | awk '{print $1}'
}

write_fixture_journal() {
  local operation="$1" backup="$2" before_hash="$3" after_hash="$4"
  mkdir -p "$HEADSET_REMOTE_STATE_DIR"
  jq -n \
    --arg operation "$operation" \
    --arg config_file "$HEADSET_REMOTE_CONFIG" \
    --arg backup_path "$backup" \
    --arg before_hash "$before_hash" \
    --arg after_hash "$after_hash" '
      {
        schema_version: 1,
        operation: $operation,
        config_file: $config_file,
        backup_path: $backup_path,
        before_hash: $before_hash,
        after_hash: $after_hash,
        created_at: "fixture"
      }
    ' > "$HEADSET_REMOTE_STATE_DIR/pending-operation.json"
}

test_list_presets() {
  run_cli list-presets
  assert_success || return
  assert_output_contains "wispr-flow"
}

test_version_reports_1_0_1() {
  run_cli version
  assert_success || return
  assert_eq "1.0.1" "$RUN_OUTPUT" "CLI version was not bumped"
}

test_detect_uses_selected_preset_device_in_either_option_order() {
  run_cli detect --json
  assert_success || return
  jq -e '.preset_id == "wispr-flow" and .target_count == 1' <<<"$RUN_OUTPUT" >/dev/null \
    || fail_assertion "detect did not default to the wispr-flow preset" || return

  local copy="$SANDBOX/detect-presets"
  local preset_dir="$copy/presets/alternate-device"
  mkdir -p "$preset_dir" "$copy/devices"

  jq '
    .id = "alternate-device"
    | .name = "Alternate device"
    | .device_file = "alternate-device.json"
    | .rule_description = "[inline-headset-remote:alternate-device:v1] fixture"
  ' "$REPO_ROOT/presets/wispr-flow/manifest.json" > "$preset_dir/manifest.json" || return
  jq '
    .title = "Alternate device fixture"
    | .rules[0].description = "[inline-headset-remote:alternate-device:v1] fixture"
    | .rules[0].manipulators |= map(
        .conditions |= map(
          if .type == "device_if"
          then .identifiers = [{"vendor_id": 1234, "product_id": 5678, "is_consumer": true}]
          else .
          end
        )
      )
  ' "$REPO_ROOT/presets/wispr-flow/karabiner.json" > "$preset_dir/karabiner.json" || return
  jq '
    .id = "alternate-device"
    | .karabiner_identifiers = {"vendor_id": 1234, "product_id": 5678, "is_consumer": true}
    | .detection = {"product": "Alternate Headset", "transport": "USB", "is_consumer": true}
    | .generic_identifier_warning = false
  ' "$REPO_ROOT/devices/apple-audio-headset.json" > "$copy/devices/alternate-device.json" || return
  jq -n '[{
    manufacturer: "Fixture",
    product: "Alternate Headset",
    transport: "USB",
    device_identifiers: {vendor_id: 1234, product_id: 5678, is_consumer: true}
  }]' > "$copy/alternate-devices.json" || return

  export HEADSET_REMOTE_PRESETS_DIR="$copy/presets"
  export HEADSET_REMOTE_DEVICES_DIR="$copy/devices"
  export MOCK_DEVICES_JSON="$copy/alternate-devices.json"

  run_cli detect --preset alternate-device --json
  assert_success || return
  jq -e '
    .preset_id == "alternate-device"
    and .target_count == 1
    and .generic_match_count == 1
    and .karabiner_identifiers.vendor_id == 1234
    and .detection.product == "Alternate Headset"
  ' <<<"$RUN_OUTPUT" >/dev/null || fail_assertion "detect did not use the selected preset device" || return

  run_cli detect --json --preset alternate-device
  assert_success || return
  jq -e '.preset_id == "alternate-device" and .target_count == 1' <<<"$RUN_OUTPUT" >/dev/null \
    || fail_assertion "detect did not accept --json before --preset"
}

test_all_bundled_presets_pass_runtime_dry_run() {
  local original preset_dir preset_id
  original="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  for preset_dir in "$REPO_ROOT"/presets/*(N/); do
    [[ -f "$preset_dir/manifest.json" ]] || continue
    preset_id="$(jq -r '.id' "$preset_dir/manifest.json")" || return
    run_cli install --preset "$preset_id" --dry-run --allow-generic-match
    assert_success || return
    assert_output_matches 'dry.?run|no files were changed' || return
    assert_file_unchanged "$original" "$HEADSET_REMOTE_CONFIG" || return
  done
}

test_install_preserves_unrelated_configuration() {
  local before_global before_secondary
  before_global="$(jq -S '.global' "$HEADSET_REMOTE_CONFIG")"
  before_secondary="$(jq -S '.profiles[] | select(.name == "Secondary")' "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  assert_valid_json "$HEADSET_REMOTE_CONFIG" || return
  assert_eq 2 "$(selected_rules_count)" "install should append exactly one rule" || return
  assert_eq 2 "$(selected_devices_count)" "install should append exactly one device" || return
  assert_eq "$before_global" "$(jq -S '.global' "$HEADSET_REMOTE_CONFIG")" "global settings changed" || return
  assert_eq "$before_secondary" "$(jq -S '.profiles[] | select(.name == "Secondary")' "$HEADSET_REMOTE_CONFIG")" "unselected profile changed" || return
  jq -e '.profiles[] | select(.selected == true) | .complex_modifications.rules[] | select(.description == "Keep this unrelated rule")' "$HEADSET_REMOTE_CONFIG" >/dev/null || fail_assertion "unrelated rule was removed" || return
  jq -e '.profiles[] | select(.selected == true) | .devices[] | select(.identifiers.vendor_id == 1452 and .identifiers.product_id == 610)' "$HEADSET_REMOTE_CONFIG" >/dev/null || fail_assertion "unrelated device was removed"
}

test_install_is_idempotent() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  local after_first
  after_first="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  assert_file_unchanged "$after_first" "$HEADSET_REMOTE_CONFIG" || return
  assert_eq 2 "$(selected_rules_count)" "second install duplicated a rule" || return
  assert_eq 2 "$(selected_devices_count)" "second install duplicated a device"
}

test_dry_run_does_not_mutate() {
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --dry-run --allow-generic-match
  assert_success || return
  [[ "$RUN_OUTPUT" != *"current_device="* ]] || fail_assertion "dry-run leaked an internal variable declaration" || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG" || return
  assert_output_matches 'dry.?run|would (install|change)|preview' || return
  [[ -z "$(find "$HEADSET_REMOTE_STATE_DIR" -type f -print -quit)" ]] || fail_assertion "dry-run wrote state or backup files"
}

test_install_rejects_old_karabiner_before_mutation() {
  export MOCK_KARABINER_VERSION=15.3.9
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --allow-generic-match
  assert_failure || return
  assert_output_matches 'Karabiner.*15[.]3[.]9.*(old|require)|15[.]4[.]0.*(newer|required)' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG" || return
  [[ -z "$(find "$HEADSET_REMOTE_STATE_DIR" -type f -print -quit)" ]] \
    || fail_assertion "version rejection wrote state or backup files"
}

test_install_hint_uses_shell_escaped_executable_path() {
  local copy="$SANDBOX/checkout's \$safe; directory"
  mkdir -p "$copy"
  cp -R "$REPO_ROOT/bin" "$REPO_ROOT/devices" "$REPO_ROOT/presets" "$copy/" || return

  run_cli_at "$copy/bin/headset-remote" install --preset wispr-flow --allow-generic-match
  assert_success || return
  local hint hint_output hint_status
  hint="$(print -r -- "$RUN_OUTPUT" | sed -n 's/^INFO  Run: //p' | tail -1)"
  [[ -n "$hint" ]] || fail_assertion "post-install doctor hint was missing" || return
  zsh -n -c "$hint" || fail_assertion "post-install doctor hint was not valid shell syntax" || return
  hint_output="$(zsh -c "$hint" 2>&1)"
  hint_status=$?
  (( hint_status == 0 )) || fail_assertion "post-install doctor hint failed when executed: $hint_output" || return
  [[ "$hint_output" == *"Doctor result: 0 error(s)"* ]] \
    || fail_assertion "post-install doctor hint did not execute the copied CLI"
}

test_single_generic_match_requires_acknowledgement() {
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow
  assert_failure || return
  assert_output_matches 'generic|0/0|allow-generic-match|acknowledge' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG"
}

test_generic_match_refuses_then_override_installs() {
  export MOCK_DEVICES_JSON="$FIXTURE_ROOT/devices/two-generic-consumers.json"
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow
  assert_failure || return
  assert_output_matches 'generic|0/0|collision|multiple|more than one|ambiguous|acknowledge' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG" || return

  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  assert_eq 2 "$(selected_rules_count)" "collision override did not install"
}

test_disconnected_refuses_then_override_installs() {
  export MOCK_DEVICES_JSON="$FIXTURE_ROOT/devices/none.json"
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --allow-generic-match
  assert_failure || return
  assert_output_matches 'not (connected|found)|no (connected|matching|compatible|headset)|headset.*(not|no|detected)' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG" || return

  run_cli install --preset wispr-flow --allow-generic-match --allow-disconnected
  assert_success || return
  assert_eq 2 "$(selected_rules_count)" "disconnected override did not install"
}

test_nonzero_headset_is_not_a_target_for_zero_id_preset() {
  export MOCK_DEVICES_JSON="$FIXTURE_ROOT/devices/headset-nonzero-with-unrelated-zero.json"
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --allow-generic-match
  assert_failure || return
  assert_output_matches 'not (connected|found)|no (connected|matching|compatible)|headset.*(not|no|detected)|identifier' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG" || return

  run_cli install --preset wispr-flow --allow-generic-match --allow-disconnected
  assert_success || return
  assert_eq 2 "$(selected_rules_count)" "disconnected override did not allow the intentionally unmatched preset"
}

test_zero_id_manifest_cannot_disable_generic_acknowledgement() {
  local copy="$SANDBOX/repository"
  mkdir -p "$copy"
  cp -R "$REPO_ROOT/devices" "$REPO_ROOT/presets" "$copy/" || return
  local device="$copy/devices/apple-audio-headset.json"
  jq '.generic_identifier_warning = false' "$device" > "$SANDBOX/unsafe-device.json" || return
  mv "$SANDBOX/unsafe-device.json" "$device"
  export HEADSET_REMOTE_PRESETS_DIR="$copy/presets"
  export HEADSET_REMOTE_DEVICES_DIR="$copy/devices"
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow
  assert_failure || return
  assert_output_matches 'generic|0/0|allow-generic-match|warning|schema|safety|invalid' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG"
}

test_uninstall_removes_only_owned_changes() {
  local original
  original="$(jq -S . "$HEADSET_REMOTE_CONFIG")"
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  local installed
  installed="$(jq -S . "$HEADSET_REMOTE_CONFIG")"
  run_cli uninstall --dry-run
  assert_success || return
  assert_file_unchanged "$installed" "$HEADSET_REMOTE_CONFIG" || return

  run_cli uninstall
  assert_success || return
  assert_file_unchanged "$original" "$HEADSET_REMOTE_CONFIG"
}

test_preset_switch_keeps_one_owned_rule_and_original_uninstall_baseline() {
  local original
  original="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  run_cli install --preset f18-dictation --allow-generic-match
  assert_success || return

  local owned_count
  owned_count="$(jq '[
    .profiles[] | select(.selected == true)
    | (.complex_modifications.rules // [])[]
    | select((.description // "") | startswith("[inline-headset-remote:"))
  ] | length' "$HEADSET_REMOTE_CONFIG")"
  assert_eq 1 "$owned_count" "preset switch left more than one managed rule" || return
  jq -e '
    [.profiles[] | select(.selected == true) | (.complex_modifications.rules // [])[]
      | select((.description // "") | startswith("[inline-headset-remote:f18-dictation:"))]
    | length == 1
  ' "$HEADSET_REMOTE_CONFIG" >/dev/null || fail_assertion "f18-dictation did not replace the Wispr Flow rule" || return
  jq -e '
    .preset_id == "f18-dictation"
    and .original_rule == null
    and .original_device == null
  ' "$HEADSET_REMOTE_STATE_DIR/installation.json" >/dev/null \
    || fail_assertion "preset switch discarded the original uninstall baseline" || return

  run_cli uninstall
  assert_success || return
  assert_file_unchanged "$original" "$HEADSET_REMOTE_CONFIG"
}

test_user_edited_managed_rule_aborts_uninstall() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  jq '
    .profiles |= map(
      if .selected == true then
        .complex_modifications.rules |= map(
          if ((.description // "") | startswith("[inline-headset-remote:"))
          then .manipulators[0].to[0].key_code = "f19"
          else . end
        )
      else . end
    )
  ' "$HEADSET_REMOTE_CONFIG" > "$SANDBOX/tampered-rule.json" || return
  mv "$SANDBOX/tampered-rule.json" "$HEADSET_REMOTE_CONFIG"
  local tampered
  tampered="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli uninstall
  assert_failure || return
  assert_output_matches 'managed rule.*(edited|changed)|refus|preserv' || return
  assert_file_unchanged "$tampered" "$HEADSET_REMOTE_CONFIG"
}

test_user_edited_managed_device_aborts_uninstall() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  jq '
    .profiles |= map(
      if .selected == true then
        .devices |= map(
          if (
            (.identifiers.vendor_id // -1) == 0
            and (.identifiers.product_id // -1) == 0
            and (.identifiers.is_consumer // false) == true
          ) then .ignore = true
          else . end
        )
      else . end
    )
  ' "$HEADSET_REMOTE_CONFIG" > "$SANDBOX/tampered-device.json" || return
  mv "$SANDBOX/tampered-device.json" "$HEADSET_REMOTE_CONFIG"
  local tampered
  tampered="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli uninstall
  assert_failure || return
  assert_output_matches 'managed device.*(edited|changed)|refus|preserv' || return
  assert_file_unchanged "$tampered" "$HEADSET_REMOTE_CONFIG"
}

test_corrupt_original_rule_state_aborts_uninstall() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  local state="$HEADSET_REMOTE_STATE_DIR/installation.json"
  jq '.original_rule = "corrupt-not-a-rule-object"' "$state" > "$SANDBOX/corrupt-state.json" || return
  mv "$SANDBOX/corrupt-state.json" "$state"
  local installed
  installed="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli uninstall
  assert_failure || return
  assert_output_matches 'state|original_rule|schema|invalid|corrupt|object' || return
  assert_file_unchanged "$installed" "$HEADSET_REMOTE_CONFIG"
}

test_semantically_malformed_original_rule_state_aborts_uninstall() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  local state="$HEADSET_REMOTE_STATE_DIR/installation.json"
  jq '.original_rule = {
    description: "looks superficially valid",
    manipulators: ["not-a-manipulator-object"]
  }' "$state" > "$SANDBOX/semantic-corrupt-state.json" || return
  mv "$SANDBOX/semantic-corrupt-state.json" "$state"
  local installed
  installed="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli uninstall
  assert_failure || return
  assert_output_matches 'state|original_rule|schema|invalid|unsafe|manipulator' || return
  assert_file_unchanged "$installed" "$HEADSET_REMOTE_CONFIG"
}

test_active_lock_refuses_concurrent_install() {
  mkdir -p "$HEADSET_REMOTE_STATE_DIR/operation.lock"
  jq -n --argjson pid "$$" '{pid: $pid, started_at: "fixture", command: "fixture"}' \
    > "$HEADSET_REMOTE_STATE_DIR/operation.lock/owner.json" || return
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --allow-generic-match
  assert_failure || return
  assert_output_matches 'another.*operation|in progress|lock|concurrent' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG" || return
  [[ -d "$HEADSET_REMOTE_STATE_DIR/operation.lock" ]] \
    || fail_assertion "refused install removed a lock it did not own"
}

test_stale_owned_lock_is_recovered() {
  local lock="$HEADSET_REMOTE_STATE_DIR/operation.lock"
  mkdir -p "$lock"
  jq -n '{pid: 2147483647, started_at: "fixture", command: "fixture"}' \
    > "$lock/owner.json" || return

  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  assert_output_matches 'stale|recover' || return
  assert_eq 2 "$(selected_rules_count)" "install did not proceed after stale-lock recovery" || return
  [[ ! -e "$lock" ]] || fail_assertion "recovered operation lock remained after successful install"
}

test_install_clears_before_hash_journal_and_proceeds() {
  local backup_dir="$HEADSET_REMOTE_STATE_DIR/backups"
  local backup="$backup_dir/interrupted-install-before.json"
  mkdir -p "$backup_dir"
  cp "$HEADSET_REMOTE_CONFIG" "$backup"
  local before_hash after_hash
  before_hash="$(fixture_sha256 "$HEADSET_REMOTE_CONFIG")" || return
  after_hash="$(print -n fixture-after-side | /usr/bin/shasum -a 256 | awk '{print $1}')" || return
  write_fixture_journal install "$backup" "$before_hash" "$after_hash" || return

  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  assert_output_matches 'clearing.*interrupted|live configuration was not replaced|journal' || return
  [[ ! -e "$HEADSET_REMOTE_STATE_DIR/pending-operation.json" ]] \
    || fail_assertion "before-hash recovery left the journal behind" || return
  assert_eq 2 "$(selected_rules_count)" "install did not proceed after clearing the journal"
}

test_install_rolls_back_after_hash_without_state_then_proceeds() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  local state="$HEADSET_REMOTE_STATE_DIR/installation.json"
  local backup before_hash after_hash
  backup="$(jq -r '.backup_path' "$state")" || return
  before_hash="$(jq -r '.config_hash_before' "$state")" || return
  after_hash="$(jq -r '.config_hash_after' "$state")" || return
  [[ "$(fixture_sha256 "$HEADSET_REMOTE_CONFIG")" == "$after_hash" ]] \
    || fail_assertion "fixture live config does not match the recorded after hash" || return
  rm -f "$state"
  write_fixture_journal install "$backup" "$before_hash" "$after_hash" || return

  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  assert_output_matches 'rolling back.*interrupted|rollback' || return
  [[ ! -e "$HEADSET_REMOTE_STATE_DIR/pending-operation.json" ]] \
    || fail_assertion "after-hash recovery left the journal behind" || return
  [[ -f "$state" ]] || fail_assertion "install did not commit state after journal rollback" || return
  assert_eq 1 "$(jq '[
    .profiles[] | select(.selected == true)
    | (.complex_modifications.rules // [])[]
    | select((.description // "") | startswith("[inline-headset-remote:"))
  ] | length' "$HEADSET_REMOTE_CONFIG")" "recovery produced duplicate managed rules"
}

test_interrupted_preset_switch_preserves_prior_state_across_unrelated_edit() {
  local expected_baseline="$SANDBOX/user-edited-baseline.json"
  jq '.global.user_edit_after_install = true' "$HEADSET_REMOTE_CONFIG" > "$expected_baseline" || return

  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  jq '.global.user_edit_after_install = true' "$HEADSET_REMOTE_CONFIG" \
    > "$SANDBOX/wispr-with-user-edit.json" || return
  mv "$SANDBOX/wispr-with-user-edit.json" "$HEADSET_REMOTE_CONFIG"

  local switch_backup="$HEADSET_REMOTE_STATE_DIR/backups/interrupted-f18-switch.json"
  cp "$HEADSET_REMOTE_CONFIG" "$switch_backup"
  local before_hash
  before_hash="$(fixture_sha256 "$HEADSET_REMOTE_CONFIG")" || return

  local f18_rule
  f18_rule="$(jq -c '.rules[0]' "$REPO_ROOT/presets/f18-dictation/karabiner.json")" || return
  jq --argjson rule "$f18_rule" '
    .profiles |= map(
      if .selected == true then
        .complex_modifications.rules |= map(
          if ((.description // "") | startswith("[inline-headset-remote:"))
          then $rule
          else . end
        )
      else . end
    )
  ' "$HEADSET_REMOTE_CONFIG" > "$SANDBOX/interrupted-f18-candidate.json" || return
  mv "$SANDBOX/interrupted-f18-candidate.json" "$HEADSET_REMOTE_CONFIG"
  local after_hash
  after_hash="$(fixture_sha256 "$HEADSET_REMOTE_CONFIG")" || return
  write_fixture_journal install "$switch_backup" "$before_hash" "$after_hash" || return

  run_cli install --preset f18-dictation --allow-generic-match
  assert_success || return
  assert_output_matches 'rolling back.*interrupted|rollback' || return
  [[ ! -e "$HEADSET_REMOTE_STATE_DIR/pending-operation.json" ]] \
    || fail_assertion "interrupted preset-switch journal was not cleared" || return

  run_cli uninstall
  assert_success || return
  assert_eq 0 "$(jq '[
    .profiles[]
    | (.complex_modifications.rules // [])[]
    | select((.description // "") | startswith("[inline-headset-remote:"))
  ] | length' "$HEADSET_REMOTE_CONFIG")" "uninstall left a prior managed rule after switch recovery" || return
  assert_file_unchanged "$(jq -S . "$expected_baseline")" "$HEADSET_REMOTE_CONFIG"
}

test_pending_after_hash_journal_blocks_dry_runs_without_mutation() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  local state="$HEADSET_REMOTE_STATE_DIR/installation.json"
  local backup before_hash after_hash journal="$HEADSET_REMOTE_STATE_DIR/pending-operation.json"
  backup="$(jq -r '.backup_path' "$state")" || return
  before_hash="$(jq -r '.config_hash_before' "$state")" || return
  after_hash="$(jq -r '.config_hash_after' "$state")" || return
  write_fixture_journal install "$backup" "$before_hash" "$after_hash" || return

  local config_snapshot state_snapshot journal_snapshot
  config_snapshot="$(jq -S . "$HEADSET_REMOTE_CONFIG")"
  state_snapshot="$(jq -S . "$state")"
  journal_snapshot="$(jq -S . "$journal")"

  run_cli install --preset f18-dictation --dry-run --allow-generic-match
  assert_failure || return
  assert_output_matches 'pending operation|requires recovery|non-dry-run' || return
  assert_file_unchanged "$config_snapshot" "$HEADSET_REMOTE_CONFIG" || return
  assert_eq "$state_snapshot" "$(jq -S . "$state")" "install dry-run changed managed state" || return
  assert_eq "$journal_snapshot" "$(jq -S . "$journal")" "install dry-run changed pending journal" || return

  run_cli uninstall --dry-run
  assert_failure || return
  assert_output_matches 'pending operation|requires recovery|non-dry-run' || return
  assert_file_unchanged "$config_snapshot" "$HEADSET_REMOTE_CONFIG" || return
  assert_eq "$state_snapshot" "$(jq -S . "$state")" "uninstall dry-run changed managed state" || return
  assert_eq "$journal_snapshot" "$(jq -S . "$journal")" "uninstall dry-run changed pending journal"
}

test_pending_after_hash_rejects_tampered_backup_without_mutation() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  local state="$HEADSET_REMOTE_STATE_DIR/installation.json"
  local backup before_hash after_hash journal="$HEADSET_REMOTE_STATE_DIR/pending-operation.json"
  backup="$(jq -r '.backup_path' "$state")" || return
  before_hash="$(jq -r '.config_hash_before' "$state")" || return
  after_hash="$(jq -r '.config_hash_after' "$state")" || return
  jq '.global.tampered_backup = true' "$backup" > "$SANDBOX/tampered-backup.json" || return
  mv "$SANDBOX/tampered-backup.json" "$backup"
  rm -f "$state"
  write_fixture_journal install "$backup" "$before_hash" "$after_hash" || return

  local config_snapshot journal_snapshot
  config_snapshot="$(jq -S . "$HEADSET_REMOTE_CONFIG")"
  journal_snapshot="$(jq -S . "$journal")"
  run_cli install --preset f18-dictation --allow-generic-match
  assert_failure || return
  assert_output_matches 'backup.*(match|hash|recorded|tamper)|pre-operation configuration|integrity' || return
  assert_file_unchanged "$config_snapshot" "$HEADSET_REMOTE_CONFIG" || return
  [[ ! -e "$state" ]] || fail_assertion "failed recovery unexpectedly created managed state" || return
  assert_eq "$journal_snapshot" "$(jq -S . "$journal")" "failed recovery changed the pending journal"
}

test_pending_journal_rejects_backup_path_traversal() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  local state="$HEADSET_REMOTE_STATE_DIR/installation.json"
  local real_backup before_hash after_hash journal="$HEADSET_REMOTE_STATE_DIR/pending-operation.json"
  real_backup="$(jq -r '.backup_path' "$state")" || return
  before_hash="$(jq -r '.config_hash_before' "$state")" || return
  after_hash="$(jq -r '.config_hash_after' "$state")" || return
  local outside="$HEADSET_REMOTE_STATE_DIR/outside-backup.json"
  cp "$real_backup" "$outside"
  rm -f "$state"
  write_fixture_journal install "$HEADSET_REMOTE_STATE_DIR/backups/../outside-backup.json" "$before_hash" "$after_hash" || return

  local config_snapshot journal_snapshot
  config_snapshot="$(jq -S . "$HEADSET_REMOTE_CONFIG")"
  journal_snapshot="$(jq -S . "$journal")"
  run_cli install --preset f18-dictation --allow-generic-match
  assert_failure || return
  assert_output_matches 'outside.*backup|path|unsafe|travers' || return
  assert_file_unchanged "$config_snapshot" "$HEADSET_REMOTE_CONFIG" || return
  assert_eq "$journal_snapshot" "$(jq -S . "$journal")" "path-traversal refusal changed the journal"
}

test_pending_journal_rejects_symlinked_backup() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  local state="$HEADSET_REMOTE_STATE_DIR/installation.json"
  local real_backup before_hash after_hash journal="$HEADSET_REMOTE_STATE_DIR/pending-operation.json"
  real_backup="$(jq -r '.backup_path' "$state")" || return
  before_hash="$(jq -r '.config_hash_before' "$state")" || return
  after_hash="$(jq -r '.config_hash_after' "$state")" || return
  local symlink="$HEADSET_REMOTE_STATE_DIR/backups/symlinked-backup.json"
  ln -s "${real_backup:t}" "$symlink"
  rm -f "$state"
  write_fixture_journal install "$symlink" "$before_hash" "$after_hash" || return

  local config_snapshot journal_snapshot
  config_snapshot="$(jq -S . "$HEADSET_REMOTE_CONFIG")"
  journal_snapshot="$(jq -S . "$journal")"
  run_cli install --preset f18-dictation --allow-generic-match
  assert_failure || return
  assert_output_matches 'backup.*(unsafe|symlink|regular)|missing or unsafe' || return
  assert_file_unchanged "$config_snapshot" "$HEADSET_REMOTE_CONFIG" || return
  assert_eq "$journal_snapshot" "$(jq -S . "$journal")" "symlink refusal changed the journal"
}

test_duplicate_selected_profiles_are_rejected() {
  jq '.profiles |= map(.selected = true)' "$HEADSET_REMOTE_CONFIG" > "$SANDBOX/duplicate-selected.json" || return
  mv "$SANDBOX/duplicate-selected.json" "$HEADSET_REMOTE_CONFIG"
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --allow-generic-match
  assert_failure || return
  assert_output_matches 'exactly one selected|selected profile|found 2|ambiguous' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG"
}

test_duplicate_profile_names_are_rejected() {
  jq '.profiles[1].name = .profiles[0].name' "$HEADSET_REMOTE_CONFIG" > "$SANDBOX/duplicate-names.json" || return
  mv "$SANDBOX/duplicate-names.json" "$HEADSET_REMOTE_CONFIG"
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --profile Primary --allow-generic-match
  assert_failure || return
  assert_output_matches 'must exist exactly once|found 2|duplicate|ambiguous' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG"
}

test_backups_are_listed_and_latest_can_be_restored() {
  local original
  original="$(jq -S . "$HEADSET_REMOTE_CONFIG")"
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  local backup="" file
  for file in "${(@f)$(find "$HEADSET_REMOTE_STATE_DIR" -type f -name '*.json')}"; do
    if jq -e '.profiles | type == "array"' "$file" >/dev/null 2>&1; then
      backup="$file"
      break
    fi
  done
  [[ -n "$backup" ]] || fail_assertion "install did not create a complete JSON configuration backup" || return
  assert_valid_json "$backup" || return

  run_cli backups
  assert_success || return
  assert_output_contains "${backup:t}" || return

  jq '.global.fixture_mutation = true' "$HEADSET_REMOTE_CONFIG" > "$SANDBOX/mutated.json" || return
  mv "$SANDBOX/mutated.json" "$HEADSET_REMOTE_CONFIG"
  run_cli restore --latest --dry-run
  assert_success || return
  jq -e '.global.fixture_mutation == true' "$HEADSET_REMOTE_CONFIG" >/dev/null || fail_assertion "restore dry-run changed the live config" || return

  run_cli restore --latest
  assert_failure || return

  run_cli restore --latest --force
  assert_success || return
  assert_file_unchanged "$original" "$HEADSET_REMOTE_CONFIG"
}

test_created_backups_are_private_mode_600() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  local backup
  backup="$(jq -r '.backup_path' "$HEADSET_REMOTE_STATE_DIR/installation.json")" || return
  [[ -f "$backup" ]] || fail_assertion "managed state does not reference an existing backup" || return
  assert_eq 600 "$(stat -f '%Lp' "$backup")" "backup permissions are not private"
}

test_restore_rejects_non_config_json_without_mutation() {
  local invalid_backup="$SANDBOX/not-a-karabiner-config.json"
  print -r -- '{}' > "$invalid_backup"
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli restore --backup "$invalid_backup" --force
  assert_failure || return
  assert_output_matches 'backup|configuration|profiles|schema|invalid' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG"
}

test_backups_list_and_restore_newest_first() {
  local backup_dir="$HEADSET_REMOTE_STATE_DIR/backups"
  local oldest="$backup_dir/20200101T000000Z-oldest.json"
  local newest="$backup_dir/20210101T000000Z-newest.json"
  mkdir -p "$backup_dir"
  jq '.global.fixture_backup = "oldest"' "$HEADSET_REMOTE_CONFIG" > "$oldest" || return
  jq '.global.fixture_backup = "newest"' "$HEADSET_REMOTE_CONFIG" > "$newest" || return
  touch -t 202001010000 "$oldest"
  touch -t 202101010000 "$newest"

  run_cli backups
  assert_success || return
  local first_line="${RUN_OUTPUT%%$'\n'*}"
  assert_eq "$newest" "$first_line" "backups did not list the newest snapshot first" || return

  run_cli restore --latest --force
  assert_success || return
  jq -e '.global.fixture_backup == "newest"' "$HEADSET_REMOTE_CONFIG" >/dev/null \
    || fail_assertion "restore --latest did not choose the newest backup"
}

test_doctor_reports_healthy_fixture() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return
  run_cli doctor --preset wispr-flow
  assert_success || return
  assert_output_matches 'healthy|pass|ready|installed'
}

test_doctor_uses_recorded_nonselected_profile_and_accepts_explicit_profile() {
  run_cli install --preset wispr-flow --profile Secondary --allow-generic-match
  assert_success || return
  jq -e '.profile == "Secondary"' "$HEADSET_REMOTE_STATE_DIR/installation.json" >/dev/null \
    || fail_assertion "install did not record the explicitly targeted profile" || return

  run_cli doctor --preset wispr-flow
  assert_success || return
  assert_output_matches 'exactly matches|state matches|doctor result: 0 error' || return

  run_cli doctor --preset wispr-flow --profile Secondary
  assert_success || return
  assert_output_matches 'exactly matches|state matches|doctor result: 0 error'
}

test_doctor_fails_for_unhealthy_driver() {
  export MOCK_GUIDANCE_JSON="$FIXTURE_ROOT/guidance/unhealthy.json"
  run_cli doctor
  assert_failure || return
  assert_output_matches 'driver|virtual|parse|fail|error'
}

test_doctor_fails_when_cli_is_missing() {
  export HEADSET_REMOTE_KARABINER_CLI="$SANDBOX/missing-karabiner-cli"
  run_cli doctor
  assert_failure || return
  assert_output_matches 'karabiner.*(cli|missing|not found|install)'
}

test_doctor_rejects_managed_rule_with_same_description_but_changed_output() {
  run_cli install --preset wispr-flow --allow-generic-match
  assert_success || return

  jq '
    .profiles |= map(
      if .selected == true then
        .complex_modifications.rules |= map(
          if ((.description // "") | startswith("[inline-headset-remote:wispr-flow:")) then
            .manipulators |= map(
              if .from.consumer_key_code == "play_or_pause"
              then .to = [{"key_code": "f20"}]
              else . end
            )
          else . end
        )
      else . end
    )
  ' "$HEADSET_REMOTE_CONFIG" > "$SANDBOX/changed-center-output.json" || return
  mv "$SANDBOX/changed-center-output.json" "$HEADSET_REMOTE_CONFIG"
  local changed
  changed="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli doctor --preset wispr-flow
  assert_failure || return
  assert_output_matches 'rule.*(changed|mismatch|different|invalid|expected)|managed.*rule|integrity|different behavior|state differs' || return
  assert_file_unchanged "$changed" "$HEADSET_REMOTE_CONFIG"
}

test_malformed_config_is_rejected_without_replacement() {
  cp "$FIXTURE_ROOT/config/karabiner-malformed.json" "$HEADSET_REMOTE_CONFIG"
  local before
  before="$(cat "$HEADSET_REMOTE_CONFIG")"
  run_cli install --preset wispr-flow
  assert_failure || return
  assert_output_matches 'config|json|parse|malformed|invalid' || return
  assert_eq "$before" "$(cat "$HEADSET_REMOTE_CONFIG")" "malformed config was overwritten"
}

test_malformed_preset_is_rejected_without_mutation() {
  [[ -d "$REPO_ROOT/presets" && -x "$CLI" ]] || skip_test "implementation or presets not present yet" || return
  local copy="$SANDBOX/repository"
  mkdir -p "$copy"
  cp -R "$REPO_ROOT/bin" "$REPO_ROOT/devices" "$REPO_ROOT/presets" "$copy/" || return
  local preset="$copy/presets/wispr-flow/karabiner.json"
  [[ -f "$preset" ]] || fail_assertion "expected preset rule at presets/wispr-flow/karabiner.json" || return
  print -r -- '{"rules":[' > "$preset"
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli_at "$copy/bin/headset-remote" install --preset wispr-flow --allow-generic-match
  assert_failure || return
  assert_output_matches 'preset|json|parse|malformed|invalid' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG"
}

test_preset_with_key_up_shell_command_is_rejected_without_mutation() {
  local copy="$SANDBOX/repository"
  mkdir -p "$copy"
  cp -R "$REPO_ROOT/devices" "$REPO_ROOT/presets" "$copy/" || return
  local rule="$copy/presets/wispr-flow/karabiner.json"
  local marker="$SANDBOX/shell-command-ran"
  jq --arg marker "$marker" '
    .rules[0].manipulators[0].to_after_key_up = [
      {"shell_command": ("touch " + $marker)}
    ]
  ' "$rule" > "$SANDBOX/unsafe-rule.json" || return
  mv "$SANDBOX/unsafe-rule.json" "$rule"
  export HEADSET_REMOTE_PRESETS_DIR="$copy/presets"
  export HEADSET_REMOTE_DEVICES_DIR="$copy/devices"
  local before
  before="$(jq -S . "$HEADSET_REMOTE_CONFIG")"

  run_cli install --preset wispr-flow --dry-run --allow-generic-match
  assert_failure || return
  assert_output_matches 'shell|to_after_key_up|unsafe|safety|invalid|rejected|failed' || return
  assert_file_unchanged "$before" "$HEADSET_REMOTE_CONFIG" || return
  [[ ! -e "$marker" ]] || fail_assertion "unsafe preset shell command executed"
}

test_missing_jq_is_reported_when_simulatable() {
  local empty_path="$SANDBOX/no-tools"
  mkdir -p "$empty_path"
  RUN_OUTPUT="$(PATH="$empty_path" /bin/zsh "$CLI" list-presets 2>&1)"
  RUN_STATUS=$?
  assert_failure || return
  assert_output_matches 'jq.*(required|missing|not found)|requires.*jq'
}

if [[ ! -x "$CLI" ]]; then
  print -u2 -- "Missing executable: $CLI"
  print -u2 -- "The harness is installed, but the planned CLI has not been added yet."
  exit 1
fi

run_test "list presets" test_list_presets
run_test "version reports 1.0.1" test_version_reports_1_0_1
run_test "detect uses selected preset in either option order" test_detect_uses_selected_preset_device_in_either_option_order
run_test "all bundled presets pass runtime dry-run" test_all_bundled_presets_pass_runtime_dry_run
run_test "install preserves unrelated config" test_install_preserves_unrelated_configuration
run_test "install is idempotent" test_install_is_idempotent
run_test "dry-run has no mutations" test_dry_run_does_not_mutate
run_test "install rejects old Karabiner before mutation" test_install_rejects_old_karabiner_before_mutation
run_test "install hint uses executable checkout path" test_install_hint_uses_shell_escaped_executable_path
run_test "single generic 0/0 match requires acknowledgement" test_single_generic_match_requires_acknowledgement
run_test "generic 0/0 match requires override" test_generic_match_refuses_then_override_installs
run_test "disconnected install requires override" test_disconnected_refuses_then_override_installs
run_test "nonzero headset does not satisfy zero-ID preset" test_nonzero_headset_is_not_a_target_for_zero_id_preset
run_test "zero-ID manifest cannot disable generic acknowledgement" test_zero_id_manifest_cannot_disable_generic_acknowledgement
run_test "uninstall removes owned changes only" test_uninstall_removes_only_owned_changes
run_test "preset switch preserves one rule and initial uninstall baseline" test_preset_switch_keeps_one_owned_rule_and_original_uninstall_baseline
run_test "edited managed rule aborts uninstall" test_user_edited_managed_rule_aborts_uninstall
run_test "edited managed device aborts uninstall" test_user_edited_managed_device_aborts_uninstall
run_test "corrupt original-rule state aborts uninstall" test_corrupt_original_rule_state_aborts_uninstall
run_test "semantically malformed original-rule state aborts uninstall" test_semantically_malformed_original_rule_state_aborts_uninstall
run_test "active lock refuses concurrent install" test_active_lock_refuses_concurrent_install
run_test "stale owned lock is recovered" test_stale_owned_lock_is_recovered
run_test "before-hash install journal is cleared" test_install_clears_before_hash_journal_and_proceeds
run_test "after-hash install journal rolls back without state" test_install_rolls_back_after_hash_without_state_then_proceeds
run_test "interrupted preset switch preserves prior state" test_interrupted_preset_switch_preserves_prior_state_across_unrelated_edit
run_test "pending after-hash journal blocks dry-runs" test_pending_after_hash_journal_blocks_dry_runs_without_mutation
run_test "pending after-hash journal rejects tampered backup" test_pending_after_hash_rejects_tampered_backup_without_mutation
run_test "pending journal rejects backup path traversal" test_pending_journal_rejects_backup_path_traversal
run_test "pending journal rejects symlinked backup" test_pending_journal_rejects_symlinked_backup
run_test "duplicate selected profiles are rejected" test_duplicate_selected_profiles_are_rejected
run_test "duplicate profile names are rejected" test_duplicate_profile_names_are_rejected
run_test "backups can be listed and restored" test_backups_are_listed_and_latest_can_be_restored
run_test "created backups use mode 600" test_created_backups_are_private_mode_600
run_test "restore rejects non-config JSON" test_restore_rejects_non_config_json_without_mutation
run_test "backups and restore latest choose newest" test_backups_list_and_restore_newest_first
run_test "doctor accepts healthy fixture" test_doctor_reports_healthy_fixture
run_test "doctor handles recorded non-selected profile" test_doctor_uses_recorded_nonselected_profile_and_accepts_explicit_profile
run_test "doctor rejects unhealthy driver" test_doctor_fails_for_unhealthy_driver
run_test "doctor reports missing CLI" test_doctor_fails_when_cli_is_missing
run_test "doctor rejects changed managed rule output" test_doctor_rejects_managed_rule_with_same_description_but_changed_output
run_test "malformed config is rejected" test_malformed_config_is_rejected_without_replacement
run_test "malformed preset is rejected" test_malformed_preset_is_rejected_without_mutation
run_test "preset key-up shell command is rejected" test_preset_with_key_up_shell_command_is_rejected_without_mutation
run_test "missing jq is reported" test_missing_jq_is_reported_when_simulatable

print_summary
