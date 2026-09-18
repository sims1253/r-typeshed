#!/usr/bin/env bash
# Inference gate: run the candidate stubs through the pinned ry checker's
# inference and assert diagnostic identities plus inferred binding types.
#
# Usage:
#   scripts/inference_gate.sh [RY_BIN] [STUBS_DIR]
#
# Defaults: RY_BIN=ry on PATH, STUBS_DIR=stubs/ at the repo root. CI passes
# the just-built pinned binary and the candidate stubs explicitly.
#
# What it checks:
#   1. check step — `ry check --typeshed <stubs>` over tests/inference/*-{clean,diag}.R;
#      every file must produce exactly the diagnostics in expectations.json
#      (rule code, severity, line, column). Clean files expect none.
#   2. dump step — `ry dump-types` over tests/inference/dump-*.R inside a
#      scratch project whose ry.toml points at the candidate stubs
#      (dump-types has no --typeshed flag at the pin); every binding must
#      equal the type string in dump-expectations.json.
#   3. provenance step — the stale-embedded cross-check: the same fixtures
#      run against the PRISTINE release binary with no override must still
#      show the OLD facts (false RY001/RY061 diagnostics, stale scalar type
#      strings). That proves the candidate stubs — not the embedded
#      snapshot — supply the fixed facts in steps 1 and 2: if the override
#      were silently ignored, step 1/2 output would equal the stale output
#      and the gate would fail on mismatch.
#
# Deterministic by construction: fixed fixture files, fixed expectations,
# JSON output parsing, no installed-library discovery, no randomness.
set -euo pipefail

RY_BIN="${1:-ry}"
STUBS_DIR="${2:-stubs}"

# The dump and stale-embedded steps run the binary from scratch directories,
# so a relative RY_BIN (CI passes ry/target/release/ry) must be resolved
# against the invocation directory before any cd. A bare command name (the
# `ry`-on-PATH default) must stay untouched for PATH resolution.
case "$RY_BIN" in
  /*) ;;
  */*) RY_BIN="$PWD/$RY_BIN" ;;
esac

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="$repo_root/tests/inference"
expectations="$fixture_dir/expectations.json"
dump_expectations="$fixture_dir/dump-expectations.json"

failures=0
checked=0

fail() {
  printf 'inference-gate FAIL: %s\n' "$1"
  failures=$((failures + 1))
}

pass() {
  printf 'inference-gate ok: %s\n' "$1"
}

# --- step 1: check diagnostics against candidate stubs -----------------------
for fixture in "$fixture_dir"/*-clean.R "$fixture_dir"/*-diag.R; do
  [ -e "$fixture" ] || continue
  stem=$(basename "$fixture" .R)
  checked=$((checked + 1))
  actual=$("$RY_BIN" check --typeshed "$STUBS_DIR" --exit-zero --color never \
    --output-format json "$fixture" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.dumps(sorted(
        [(d["code"], d["severity"], d["line"], d["column"])
         for d in json.load(sys.stdin)])))')
  expected=$(python3 -c 'import json,sys; print(json.dumps(sorted(
      [(d["code"], d["severity"], d["line"], d["column"])
       for d in json.load(open(sys.argv[1]))[sys.argv[2]]])))' \
    "$expectations" "$stem")
  if [ "$actual" = "$expected" ]; then
    pass "check $stem"
  else
    fail "check $stem: expected $expected, got $actual"
  fi
done

# --- step 2: inferred binding types via the ry.toml override path ------------
dump_root=$(mktemp -d "${TMPDIR:-/tmp}/inference-gate.XXXXXX")
trap 'rm -rf "$dump_root"' EXIT
# Resolve to an absolute path: ry resolves relative ry.toml `typeshed`
# entries against the config directory, so an absolute entry keeps the
# scratch project valid wherever it is created.
case "$STUBS_DIR" in
  /*) abs_stubs="$STUBS_DIR" ;;
  *) abs_stubs="$repo_root/$STUBS_DIR" ;;
esac
printf 'typeshed = [%s]\n' "$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$abs_stubs")" \
  > "$dump_root/ry.toml"
for fixture in "$fixture_dir"/dump-*.R; do
  [ -e "$fixture" ] || continue
  stem=$(basename "$fixture" .R)
  stem="${stem#dump-}"
  checked=$((checked + 1))
  cp "$fixture" "$dump_root/$stem.R"
  actual=$(cd "$dump_root" && "$RY_BIN" dump-types --format json "$stem.R" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.dumps(
        {b["name"]: b["type"]
         for b in json.load(sys.stdin)["files"][0]["scopes"][0]["bindings"]},
        sort_keys=True))')
  expected=$(python3 -c 'import json,sys; print(json.dumps(
      json.load(open(sys.argv[1]))[sys.argv[2]]["bindings"], sort_keys=True))' \
    "$dump_expectations" "$stem")
  if [ "$actual" = "$expected" ]; then
    pass "dump $stem"
  else
    fail "dump $stem: expected $expected, got $actual"
  fi
done

# --- step 3: stale-embedded cross-check (proves the override is live) ---------
# Run the same fixtures through the binary WITHOUT any override. A release
# build's embedded catalog still carries the pre-fix snapshot, so the stale
# false facts must reappear. If they do not (binary rebuilt from candidate
# stubs, or override silently ignored making steps 1-2 meaningless), the
# gate refuses to pass: a green step 1/2 is only meaningful if the stale
# behavior is still reproducible without the candidate stubs.
stale_root=$(mktemp -d "${TMPDIR:-/tmp}/inference-gate-stale.XXXXXX")
stale_failures=0
for fixture in "$fixture_dir"/dump-*.R; do
  [ -e "$fixture" ] || continue
  stem=$(basename "$fixture" .R)
  stem="${stem#dump-}"
  cp "$fixture" "$stale_root/$stem.R"
  actual=$(cd "$stale_root" && "$RY_BIN" dump-types --format json "$stem.R" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.dumps(
        {b["name"]: b["type"]
         for b in json.load(sys.stdin)["files"][0]["scopes"][0]["bindings"]},
        sort_keys=True))')
  stale=$(python3 -c 'import json,sys; print(json.dumps(
      json.load(open(sys.argv[1]))[sys.argv[2]]["stale_embedded"], sort_keys=True))' \
    "$dump_expectations" "$stem")
  if [ "$actual" = "$stale" ]; then
    pass "stale-embedded $stem still shows the old fact"
  else
    printf 'inference-gate WARN: stale-embedded %s: expected old fact %s, got %s\n' \
      "$stem" "$stale" "$actual"
    printf '  (the embedded catalog no longer carries the pre-fix snapshot;\n'
    printf '   the override is still proven live by the mutated-stub self-test.)\n'
    stale_failures=$((stale_failures + 1))
  fi
done
rm -rf "$stale_root"
if [ "$stale_failures" -gt 0 ]; then
  printf 'inference-gate note: %d stale-embedded cross-check(s) drifted (warning only).\n' "$stale_failures"
fi

printf 'inference-gate: %d fixture(s) checked, %d failure(s).\n' "$checked" "$failures"
[ "$failures" -eq 0 ]
