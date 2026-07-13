#!/bin/zsh

set -u
setopt pipe_fail

repo_root="${0:A:h:h}"
typeset -gi failures=0
typeset -gi checked=0

fail() {
  print -u2 -- "FAIL  $*"
  failures=$((failures + 1))
}

while IFS= read -r -d '' file; do
  if jq -e . "$file" >/dev/null 2>&1; then
    print -- "PASS  valid JSON: ${file#$repo_root/}"
  else
    fail "invalid JSON: ${file#$repo_root/}"
  fi
done < <(find "$repo_root" \
  -path "$repo_root/.git" -prune -o \
  -path "$repo_root/tests/fixtures/config/karabiner-malformed.json" -prune -o \
  -type f -name '*.json' -print0)

if [[ ! -d "$repo_root/presets" ]]; then
  fail "presets directory is missing"
else
  for manifest in "$repo_root"/presets/*/manifest.json(N); do
    preset_dir="${manifest:h}"
    preset_id="${preset_dir:t}"
    if ! jq -e --arg id "$preset_id" '
      .schema_version == 1
      and .id == $id
      and (.name | type == "string" and length > 0)
      and (.summary | type == "string" and length > 0)
      and (.device_file | type == "string" and length > 0)
      and (.rule_file | type == "string" and length > 0)
      and (.rule_description | type == "string" and length > 0)
      and (.mappings | type == "array" and length > 0)
    ' "$manifest" >/dev/null 2>&1; then
      fail "invalid preset manifest structure: ${manifest#$repo_root/}"
      continue
    fi

    rule_file="$preset_dir/$(jq -r '.rule_file' "$manifest")"
    device_file="$repo_root/devices/$(jq -r '.device_file' "$manifest")"
    description="$(jq -r '.rule_description' "$manifest")"
    [[ -f "$rule_file" ]] || fail "preset $preset_id references missing rule file"
    [[ -f "$device_file" ]] || fail "preset $preset_id references missing device file"
    if [[ -f "$rule_file" ]] && ! jq -e --arg description "$description" \
      '.rules | any(.description == $description)' "$rule_file" >/dev/null 2>&1; then
      fail "preset $preset_id rule_description does not match its rule file"
    else
      print -- "PASS  preset manifest links: ${manifest#$repo_root/}"
    fi
  done

  while IFS= read -r -d '' file; do
    checked=$((checked + 1))
    manifest="${file:h}/manifest.json"
    if [[ ! -f "$manifest" ]]; then
      fail "rule file has no sibling manifest: ${file#$repo_root/}"
      continue
    fi
    device_file="$repo_root/devices/$(jq -r '.device_file' "$manifest")"
    if [[ ! -f "$device_file" ]]; then
      fail "rule file references a missing device manifest: ${file#$repo_root/}"
      continue
    fi
    identifiers="$(jq -c '.karabiner_identifiers' "$device_file")"
    if jq -e --argjson identifiers "$identifiers" '
      (.title | type == "string" and length > 0)
      and (.rules | type == "array" and length > 0)
      and all(.rules[];
        (.description | type == "string" and length > 0)
        and (.manipulators | type == "array" and length > 0)
        and all(.manipulators[];
          .type == "basic"
          and (.from.consumer_key_code | type == "string" and length > 0)
          and (.to | type == "array" and length > 0)
          and all(.to[]; (.key_code | type == "string" and length > 0))
          and (.conditions | type == "array")
          and any(.conditions[];
            .type == "device_if"
            and (.identifiers | type == "array" and length > 0)
            and any(.identifiers[]; . == $identifiers)
          )
        )
      )
    ' "$file" >/dev/null 2>&1; then
      print -- "PASS  Karabiner rule structure: ${file#$repo_root/}"
    else
      fail "invalid Karabiner rule structure: ${file#$repo_root/}"
    fi
  done < <(find "$repo_root/presets" -type f -name 'karabiner.json' -print0)
fi

for file in "$repo_root"/devices/*.json(N); do
  if jq -e '
    .schema_version == 1
    and (.id | type == "string" and length > 0)
    and (.name | type == "string" and length > 0)
    and (.karabiner_identifiers.vendor_id | type == "number")
    and (.karabiner_identifiers.product_id | type == "number")
    and (.karabiner_identifiers.is_consumer | type == "boolean")
    and (.detection | type == "object")
  ' "$file" >/dev/null 2>&1; then
    print -- "PASS  device manifest structure: ${file#$repo_root/}"
  else
    fail "invalid device manifest structure: ${file#$repo_root/}"
  fi
done

(( checked > 0 )) || fail "no presets/*/karabiner.json files found"

if (( failures > 0 )); then
  print -u2
  print -u2 -- "$failures validation failure(s)"
  exit 1
fi

print
print -- "All JSON and $checked Karabiner preset rule file(s) passed validation."
