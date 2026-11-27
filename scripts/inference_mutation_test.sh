#!/usr/bin/env bash
# Mutation self-test for the inference gate: proves the gate bites.
#
# Copies stubs/ to a scratch dir, applies one deliberate schema-valid
# semantic mutation (the default reverts dnorm's return length to "arg0",
# re-creating the false fact fixed for #64), and runs the gate harness
# against the mutated tree. The gate MUST fail; this script passes only
# when the gate fails with the expected diff, and prints the gate's
# expected/actual output as the demonstration.
#
# Usage:
#   scripts/inference_mutation_test.sh [RY_BIN]
#
# Supported mutations (first arg after the binary is the mutation name):
#   density-length   dnorm return length "unknown" -> "arg0" (default)
#   as-vector-arg0   as.vector return opaque/unknown -> "arg0"
#   append-concat    append return opaque/unknown -> "concat_of_args"
#   installed-library  not a mutation: plants an R library whose dplyr NAMESPACE
#                     exports only `select`, and requires the gate to stay
#                     green, which proves it never consults installed libraries
set -euo pipefail

RY_BIN="${1:-ry}"
MUTATION="${2:-density-length}"

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
scratch=$(mktemp -d "${TMPDIR:-/tmp}/inference-selftest.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

# Hermeticity self-test. ry lets a package's installed NAMESPACE gate imports
# of a stubbed package, so a planted dplyr that exports only `select` turns
# the `filter` import in box-installed-namespace-clean.R into an RY010
# whenever library discovery is on. The first call proves the library bites.
# The gate is then run the same way, so only its own RY_NO_INSTALLED_LIBRARIES
# can keep it green. A planted library that no longer bites proves nothing, so
# it fails here.
if [ "$MUTATION" = installed-library ]; then
  planted="$scratch/library"
  mkdir -p "$planted/dplyr"
  printf 'Package: dplyr\nTitle: planted\nVersion: 0.0.1\nEncoding: UTF-8\n' \
    > "$planted/dplyr/DESCRIPTION"
  printf 'export(select)\n' > "$planted/dplyr/NAMESPACE"
  fixture="$repo_root/tests/inference/box-installed-namespace-clean.R"
  # R_LIBS comes first in ry's root order, as in R's; the other two point at
  # nothing so the machine's own libraries cannot answer instead.
  with_planted_library() {
    env -u RY_NO_INSTALLED_LIBRARIES \
      R_LIBS="$planted" R_LIBS_USER="$scratch/none" R_LIBS_SITE="$scratch/none" "$@"
  }
  bite=$(with_planted_library "$RY_BIN" check \
    --typeshed "$repo_root/stubs" --exit-zero --color never \
    --output-format json "$fixture" 2>/dev/null \
    | python3 -c 'import json,sys; print(json.dumps(sorted(d["code"] for d in json.load(sys.stdin))))')
  if [ "$bite" != '["RY010"]' ]; then
    printf 'mutation self-test FAIL: without RY_NO_INSTALLED_LIBRARIES the planted library reports %s, not ["RY010"]; the fixture no longer exercises the gate.\n' \
      "$bite" >&2
    exit 1
  fi
  printf 'planted library bites without the variable: %s\n' "$bite"
  gate_log="$scratch/gate.log"
  if with_planted_library "$repo_root/scripts/inference_gate.sh" "$RY_BIN" "$repo_root/stubs" > "$gate_log" 2>&1; then
    printf 'mutation self-test ok: gate stayed green with a planted installed library.\n'
    exit 0
  fi
  cat "$gate_log" >&2
  printf 'mutation self-test FAIL: a planted installed library changed the gate verdict; it is not hermetic.\n' >&2
  exit 1
fi

mutated="$scratch/stubs"
cp -r "$repo_root/stubs/." "$mutated/"

case "$MUTATION" in
  density-length)
    python3 - "$mutated/base/base.json" <<'EOF'
import json, sys
path = sys.argv[1]
stub = json.load(open(path))
entry = stub["functions"]["dnorm"]
assert entry["return"] == {"mode": "double", "length": "unknown", "na": True}, entry["return"]
entry["return"] = {"mode": "double", "length": "arg0", "na": True}
json.dump(stub, open(path, "w"), indent=2)
print("mutation applied: dnorm return length unknown -> arg0 (na stays true)")
EOF
    ;;
  as-vector-arg0)
    python3 - "$mutated/base/base.json" <<'EOF'
import json, sys
path = sys.argv[1]
stub = json.load(open(path))
entry = stub["functions"]["as.vector"]
assert entry["return"] == {"mode": "opaque", "length": "unknown", "na": True}, entry["return"]
entry["return"] = "arg0"
json.dump(stub, open(path, "w"), indent=2)
print("mutation applied: as.vector return opaque/unknown -> arg0")
EOF
    ;;
  append-concat)
    python3 - "$mutated/base/base.json" <<'EOF'
import json, sys
path = sys.argv[1]
stub = json.load(open(path))
entry = stub["functions"]["append"]
assert entry["return"] == {"mode": "opaque", "length": "unknown", "na": True}, entry["return"]
entry["return"] = "concat_of_args"
json.dump(stub, open(path, "w"), indent=2)
print("mutation applied: append return opaque/unknown -> concat_of_args")
EOF
    ;;
  *)
    echo "unknown mutation: $MUTATION (density-length, as-vector-arg0, append-concat)" >&2
    exit 2
    ;;
esac

# The mutation must stay schema-valid: an invalid mutant would fail the
# validate job instead of proving the inference gate bites. Hermetic like
# the gate: validation must not read an installed library either.
RY_NO_INSTALLED_LIBRARIES=1 "$RY_BIN" typeshed validate "$mutated" >/dev/null

# Each mutation must be caught by a specific fixture failing with an
# expected/actual mismatch; a bare nonzero exit could also mean a harness
# crash (missing binary, malformed JSON), which would prove nothing.
case "$MUTATION" in
  density-length)   required_failure='inference-gate FAIL: dump density' ;;
  as-vector-arg0)   required_failure='inference-gate FAIL: dump as-vector' ;;
  append-concat)    required_failure='inference-gate FAIL: dump append' ;;
esac

set +e
gate_output=$("$repo_root/scripts/inference_gate.sh" "$RY_BIN" "$mutated" 2>&1)
gate_status=$?
set -e

printf '%s\n' "$gate_output"
if [ "$gate_status" -eq 0 ]; then
  printf 'mutation self-test FAIL: gate passed on the %s mutant; it must fail.\n' "$MUTATION" >&2
  exit 1
fi
if ! grep -qF "$required_failure" <<<"$gate_output"; then
  printf 'mutation self-test FAIL: gate exited nonzero on the %s mutant without the expected %s mismatch; a harness failure proves nothing.\n' \
    "$MUTATION" "$required_failure" >&2
  exit 1
fi
printf 'mutation self-test ok: gate failed on the %s mutant with the expected %s mismatch.\n' "$MUTATION" "$required_failure"
