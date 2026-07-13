#!/bin/zsh

setopt pipe_fail

TEST_DIR="${0:A:h}"
REPO_ROOT="${TEST_DIR:h}"
FIXTURE_ROOT="$TEST_DIR/fixtures"
CLI="$REPO_ROOT/bin/headset-remote"

typeset -gi TESTS_RUN=0
typeset -gi TESTS_PASSED=0
typeset -gi TESTS_SKIPPED=0

setup_sandbox() {
  SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/headset-remote-test.XXXXXX")" || return 1
  export HOME="$SANDBOX/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export HEADSET_REMOTE_CONFIG="$SANDBOX/karabiner.json"
  export HEADSET_REMOTE_STATE_DIR="$SANDBOX/state"
  export HEADSET_REMOTE_KARABINER_CLI="$FIXTURE_ROOT/bin/karabiner_cli"
  export HEADSET_REMOTE_APP_DIR="$SANDBOX/Applications"
  export MOCK_DEVICES_JSON="$FIXTURE_ROOT/devices/one-headset.json"
  export MOCK_GUIDANCE_JSON="$FIXTURE_ROOT/guidance/healthy.json"
  export MOCK_WISPR_RUNNING=1
  export PATH="$FIXTURE_ROOT/bin:$PATH"

  mkdir -p \
    "$HOME" \
    "$HEADSET_REMOTE_STATE_DIR" \
    "$HEADSET_REMOTE_APP_DIR/Karabiner-Elements.app" \
    "$HEADSET_REMOTE_APP_DIR/Wispr Flow.app"
  cp "$FIXTURE_ROOT/config/karabiner-base.json" "$HEADSET_REMOTE_CONFIG"
}

cleanup_sandbox() {
  [[ -n "${SANDBOX:-}" && -d "$SANDBOX" ]] && rm -rf "$SANDBOX"
}

run_cli() {
  RUN_OUTPUT="$("$CLI" "$@" 2>&1)"
  RUN_STATUS=$?
}

run_cli_at() {
  local executable="$1"
  shift
  RUN_OUTPUT="$("$executable" "$@" 2>&1)"
  RUN_STATUS=$?
}

fail_assertion() {
  print -u2 -- "    assertion failed: $*"
  if [[ -n "${RUN_OUTPUT:-}" ]]; then
    print -u2 -- "    command output:"
    print -r -- "$RUN_OUTPUT" | sed 's/^/      /' >&2
  fi
  return 1
}

assert_success() {
  (( RUN_STATUS == 0 )) || fail_assertion "expected exit 0, got $RUN_STATUS"
}

assert_failure() {
  (( RUN_STATUS != 0 )) || fail_assertion "expected non-zero exit status"
}

assert_output_contains() {
  local expected="$1"
  [[ "$RUN_OUTPUT" == *"$expected"* ]] || fail_assertion "output does not contain '$expected'"
}

assert_output_matches() {
  local expected="$1"
  print -r -- "$RUN_OUTPUT" | grep -Eiq -- "$expected" || fail_assertion "output does not match /$expected/i"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="${3:-values differ}"
  [[ "$expected" == "$actual" ]] || fail_assertion "$label (expected '$expected', got '$actual')"
}

assert_file_unchanged() {
  local expected="$1"
  local file_path="$2"
  local actual
  actual="$(jq -S . "$file_path" 2>/dev/null)" || return 1
  [[ "$expected" == "$actual" ]] || fail_assertion "$file_path was unexpectedly changed"
}

assert_valid_json() {
  jq -e . "$1" >/dev/null 2>&1 || fail_assertion "$1 is not valid JSON"
}

skip_test() {
  print -- "SKIP: $*"
  return 77
}

run_test() {
  local name="$1"
  local fn="$2"
  local test_status
  TESTS_RUN=$((TESTS_RUN + 1))

  (
    setup_sandbox || exit 1
    trap cleanup_sandbox EXIT INT TERM
    "$fn"
  )
  test_status=$?

  if (( test_status == 0 )); then
    TESTS_PASSED=$((TESTS_PASSED + 1))
    print -- "PASS  $name"
  elif (( test_status == 77 )); then
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
    print -- "SKIP  $name"
  else
    print -u2 -- "FAIL  $name"
  fi
}

print_summary() {
  local failed=$((TESTS_RUN - TESTS_PASSED - TESTS_SKIPPED))
  print
  print -- "$TESTS_PASSED passed, $failed failed, $TESTS_SKIPPED skipped ($TESTS_RUN total)"
  (( failed == 0 ))
}
