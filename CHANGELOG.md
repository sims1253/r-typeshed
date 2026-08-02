# Changelog

## [Unreleased]

### Declarative semantics

- Declared defusing `eval` metadata for the base and rlang quoting helpers
  that ship stubs (ry issues #41 and #49): `base::quote`, `base::bquote`,
  and `base::expression` quote their argument as `quoted_expression`,
  matching the existing `alist` declaration (verified correct, unchanged),
  while `base::substitute` and `rlang::exprs` are `captures_promise`
  because they defuse the promise supplied by the caller of the enclosing
  function. `rlang::expr` and `rlang::quo` are `quoted_expression`; rlang
  documents `expr()` as equivalent to `bquote()`. `base::delayedAssign`
  declares only its `value` as `captures_promise`: installed R forces `x`
  as an ordinary argument to obtain the target name string (a bare symbol
  is an error), and `eval.env`/`assign.env` also evaluate normally, so all
  three are omitted. That enumeration is the complete scope within
  base/rlang: `base::evalq`, `base::local`, and `base::makeActiveBinding`
  ship no stubs, and rlang's `sym`, `abort`, `inform`, `new_formula`, and
  `new_quosure` are outside the quoting family, so none of them gained
  `eval` metadata here. Downstream note: once this is vendored, ry's
  `nse_symbol_fallback_does_not_overlap_stub_eval_modes` guard test will
  fail until the corresponding NSE list retirement (ry issues #41 and #49)
  lands in the same vendor bump — `ry typeshed validate` alone stays
  green, so vendor-without-retire is a silent trap for ry's test suite.
  Base stub revision 0.0.3, rlang stub revision 0.1.1.

### Fixed stub data

- `base::rep` return length is now `unknown`: current ry's validator
  retired the `x_times` symbolic length, which SCHEMA.md no longer
  documents. This keeps current ry and its `scripts/sync_typeshed.sh` able
  to validate and vendor this branch.

### Corrected stub data

- Completed the public formal sequences for every `base` higher-order
  signature, including `...` and controls after it, and opted them into exact,
  partial, and positional argument matching. This corrects the phantom `...`
  previously declared for `Reduce` and covers `Map`'s named-callback call shape.
- Corrected zero-argument optionality for `base::as.character`, `as.integer`,
  `as.numeric`, `as.raw`, and `rep`, and made the polymorphic `base::data`
  return opaque.
- Corrected `rlang::env_get_list(default)` optionality and added rlang's five
  exported typed missing-value constants.

### New stubs

- Added a conservative vctrs stub for `obj_is_list`, `vec_in`, `vec_set_union`,
  `vec_size`, and `vec_slice`, covering the hermetic tidyverse audit findings
  without guessing uncertain set-operation return types.

### Validation and audits

- The function-semantics provenance audit now witnesses the
  `quoted_expression` versus `captures_promise` distinction against
  installed R and rlang: the quoting helpers stay literal inside a
  forwarding function, while `substitute()` and `rlang::exprs()` defuse
  the caller's expression. `delayedAssign` witnesses pin both halves of
  its declaration: `x` is forced for the target name while the forwarded
  `value` promise is captured and deferred.
- The function-semantics audit now discovers all higher-order declarations and
  verifies their names and required/default metadata against installed R.
- Added a side-effect-safe, allowlisted zero-argument primitive audit for
  required first formals in base coercion and vector-constructor families.

## [0.4.0] - 2026-07-24

Schema 2 release for ry 0.7.0 function-semantics debt. This is a deliberate
schema bump: consumers must update to a schema-2-capable ry before vendoring
this release.

### Declarative semantics

- Added reusable `predicate` metadata and corrected `rlang::is_null` to its
  real required `x` formal, scalar non-missing logical return, and NULL
  predicate target.
- Added provenance-gated `assertion` metadata for the real standalone rlang
  `check_bool`, `check_string`, `check_number_whole`, `check_number_decimal`,
  and `check_data_frame` helpers. Only the documented `arg`/`call`
  standalone-types-check fingerprint is accepted.
- Added sound `return_length` rules: `base::intersect` preserves the exact
  fact that an empty input yields an empty result (all other bounded lengths
  remain unknown), while `paste`/`paste0` distinguish recycled values from `sep`,
  `collapse`, and `recycle0`, including all-empty, collapse, and `recycle0`
  outcomes.
- Added `conditional_scope_effect` and accurately declared `base::source`:
  default sourcing affects the current scope only at top level, while
  `local = TRUE` affects a caller frame.
- Completed base `paste`, `paste0`, and `source` public formal sequences for
  exact argument matching.

### Validation and audits

- Added a strict schema-contract validator with valid/invalid fixtures and a
  provenance audit against installed base R and rlang. The audit verifies the
  argument-binding names, controls, targets, and outcomes for every declared
  intersect, paste/paste0, source, predicate, and assertion semantic.
- CI runs the new schema validator and function-semantics provenance audit, pinned
  to schema-2 consumer ry commit `65a009be4005e0357d72b05663b913cdd4fc46f2`.
  That cross-repository bootstrap commit must be pushed to ry before this CI
  checkout can resolve; no ry release is required. Its vendored `SOURCE` may
  retain the prior r-typeshed stub commit because these final changes only
  affect CI/docs and the stubs are byte-identical.

## [0.3.0] - 2026-07-17

Driven by the ry 0.5.0 top-500 CRAN audit and the subsequent
generalization pass: stub-data fixes for the largest measured
false-positive families, three new metadata capabilities, and two new
package stubs that let ry drop its remaining hardcoded package knowledge.

### Schema additions (documented in SCHEMA.md)

- `no_return: true` function metadata: the call never returns
  (`base::stop`, `q`, `quit`; `rlang::abort`; `cli::cli_abort`). Lets the
  checker narrow guard-clause continuations from data instead of a
  hardcoded name list.
- `captures_promise` eval mode: the parameter's argument is captured
  unevaluated (rlang `enquo`/`enexpr`/`ensym`, plural forms, `quos`).
  Drives the checker's user-NSE quoting detection and forwarding.
- `data_mask_source: "<param>"` function metadata: named arguments with a
  `data_mask` eval mode evaluate inside the named parameter rather than
  the first argument. Used by formula interfaces where `data` is not
  argument 1.

### New stubs

- rlang (438 exports) and cli (213 exports), generated mechanically, with
  hand-curated `no_return` and `captures_promise` metadata.

### Fixed stub data (audit-verified false positives)

- `base::readLines` — `con` has a default (`stdin()`); was wrongly
  required (RY091 on every `readLines()`).
- `base::tapply` — gained a `higher_order` simplify spec and an opaque
  fallback return; was typed plain `list`, flagging valid array
  arithmetic (RY040).
- `base::mapply` — result kind is now `simplify` (`SIMPLIFY = TRUE`
  default); was `list_of_callback_return`.
- `base::append` — returns the concatenation of its arguments; was
  `arg0`, so `append(NULL, x)` stayed length 0 (RY001/RY002 cascades).
- `base::data`, `load`, `source`, `sys.source` — declared
  `scope_effect: unknown_bindings` (they inject statically unknowable
  bindings).
- stats/base formula interfaces (`lm`, `glm`, `aov`, …) and survival
  (`survfit`, `coxph`, `survreg`, `survdiff`) — `weights`/`subset`/
  `offset`/`id`/`cluster`/`istate` evaluate in the `data` mask via
  `data_mask_source`.
- shiny — NSE metadata for `reactive`, `observe`, `observeEvent`,
  `eventReactive`, `isolate`, the `render*` family, and `testServer`
  (quoted expressions), plus return types.

### Generators and audit

- New `scripts/param_optionality.R` (shared by `gen_typeshed.R` and
  `audit_typeshed.R`): AST-based detection of `missing(param)` /
  `maybe_missing(param)` / `nargs()` handling, so parameters that are
  optional-by-convention are never emitted as `required` (the
  `rlang::env_get(default=)` false-positive class). The audit reports
  eight base-R candidates of the same shape (`.libPaths::new`,
  `glm::data`, `read.table::file`, …) — left unchanged pending
  corpus corroboration.
- `audit_typeshed.R` — dependency-free formals comparison against the
  local R installation (`--base-formals-only` mode); re-running it now
  reports zero required/default mismatches.

## [0.2.0] - 2026-07-16

- CI runs the generators on every push: `gen_standard_globals.R --check`
  staleness gate and the namespace audit (`audit_typeshed.R`) via
  r-lib/actions setup-r.
- Audit understands re-exports; dropped the fabricated `purrr::vec_sort`
  and dbplyr test-helper stubs.
- Harvest registered-but-unexported S3 methods; declare `alist()`
  quoting.
- README: fixed the ry link; documented the NSE/base generators in the
  contribution flow.

## [0.1.0] - 2026-07-13

- Initial import of base R and ten package stubs from ry.
- The imported data was verified losslessly before the temporary import-verification script was removed.
- `scripts/gen_standard_globals.R`: mechanical generation of the base
  `globals.ambient` / `globals.ambient_functions` split from a local R
  installation (with `--check` staleness mode), plus a mechanical dataset
  inventory via `data(package = ...)`; base symbol existence is now closed
  by construction.
- Expanded `base` stubs: ambient value/function split (2000+ functions),
  datasets, and mask/eval metadata for `subset`/`transform`/`with`.
- New package stubs: dbplyr, igraph, recipes, withr, R6, S7, patrick, rex,
  rlist, box, zeallot, future, bench — covering the NSE and injected-binding
  semantics identified by the top-300 CRAN audit.
- Expanded dplyr, tidyr, and survival stubs with data-mask/tidy-select
  parameter metadata.
- New `injects` function metadata in the schema (documented in SCHEMA.md):
  declares bindings a function makes visible inside specific arguments,
  either fixed names (R6 `self`/`private`/`super`) or names taken from
  string arguments (`withr::with_tempfile`).
- `scripts/gen_nse_metadata.R`: derives `data_mask`/`tidy_select` eval
  metadata mechanically from installed packages' Rd documentation markers
  (`<data-masking>`/`<tidy-select>`); full dplyr/tidyr coverage and a new
  tidyselect stub are generated this way.
- New `scope_effect: unknown_bindings` function metadata: marks calls that
  make the caller's scope unanalyzable (`base::attach`, `Rcpp::sourceCpp`).
- Further new stubs: foreach, shiny (`testServer` injects
  `session`/`input`/`output`), Rcpp, tinytest.
