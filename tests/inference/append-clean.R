# Inference-gate fixtures: one file per case, named <family>-<expectation>.R.
#
# Files ending in `-clean.R` must check with zero diagnostics through the
# candidate stubs. Files ending in `-diag.R` must produce exactly the
# diagnostic identities listed in expectations.json (same file stem).
# Keep every file a realistic snippet; the gate asserts identities, not counts.

# PR #68 (fixes #59): append() no longer folds `after` into the result.
# append(logical(0), TRUE, after = 0L) is length 1, so the condition is legal.
a <- append(logical(0), TRUE, after = 0L)
if (a) 1L
