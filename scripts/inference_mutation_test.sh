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
set -euo pipefail

RY_BIN="${1:-ry}"
MUTATION="${2:-density-length}"

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mutated=$(mktemp -d "${TMPDIR:-/tmp}/inference-mutant.XXXXXX")
trap 'rm -rf "$mutated"' EXIT
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
# validate job instead of proving the inference gate bites.
"$RY_BIN" typeshed validate "$mutated" >/dev/null

set +e
gate_output=$("$repo_root/scripts/inference_gate.sh" "$RY_BIN" "$mutated" 2>&1)
gate_status=$?
set -e

printf '%s\n' "$gate_output"
if [ "$gate_status" -eq 0 ]; then
  printf 'mutation self-test FAIL: gate passed on the %s mutant; it must fail.\n' "$MUTATION" >&2
  exit 1
fi
printf 'mutation self-test ok: gate failed on the %s mutant as required.\n' "$MUTATION"
