# Changelog

## [Unreleased]

### Automation

- Prepare draft typeshed PRs for a named package or monthly upstream updates.
  Preserve curated entries and report signature drift for review.

### Cleanup

- Correct typed `map2_*` and `pmap_*` results to atomic vectors. Keep their
  lengths unknown because recycling and component lengths cannot be derived
  from one formal argument. Allow missing results throughout the typed map
  family. Purrr stubs are version 0.0.3.

- Complete purrr's 27 higher-order formal lists and correct seven callback
  positions and `walk2` callback arity. Bump purrr to 0.0.2 and audit both
  base and purrr against installed packages.
- Preserve structured parameters when generating NSE metadata. Generate
  schema-2 drafts, include function re-exports, and leave unknown returns
  able to contain NA.
- Replace the namespace audit's handwritten JSON readers with jsonlite.
  Resolve package names from stub headers, including Rcpp and S7.
- Use ry for schema validation and remove the duplicate R validator. Its
  fixture coverage now lives in ry. The updated consumer also discovers
  Rcpp and S7 from the parent directory, removing the extra CI paths.

### Recovered function semantics

- Restore the completed base higher-order formals and hermetic dependency
  metadata. Base is version 0.0.5, rlang is 0.1.2, and vctrs is 0.0.1.
- Keep `base::rep` return length `unknown`; the recovered `x_times` value
  is no longer supported by ry.

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

- Mark `rlang::quo(expr)` optional: `quo()` returns an empty quosure, as used
  by lazyeval compatibility helpers. Bump the rlang stub to 0.1.3 and audit
  both the empty result and the parameter declaration.

- `base::rep` return length is now `unknown`: current ry's validator
  retired the `x_times` symbolic length, which SCHEMA.md no longer
  documents. This keeps current ry and its `scripts/sync_typeshed.sh` able
  to validate and vendor this branch.

### Corrected stub data

- Completed the public formal sequences for every `base` higher-order
  signature, including `...` and controls after it, and opted them into exact,
  partial, and positional argument matching. This corrects the phantom `...`
  previously declared for `Reduce` and covers `Map`'s named-callback call shape.
- Corrected zero-argument optionality: `base::as.raw` now requires `x`
  (it rejects zero-argument calls), and the polymorphic `base::data`
  returns opaque. For `base::as.character`, `as.double`, `as.integer`,
  `as.logical`, `as.numeric`, and `rep`, R accepts the degenerate
  zero-argument calls (`as.character()` is `character(0)`, `rep()` is
  NULL`), so their `x` formals now record `required: false`. The object
  form keeps the flag as explicit schema metadata — ry decodes
  `required: false` and a bare string identically, and its exact-argument
  check is unreachable for signatures declaring `...` either way — so this
  avoids upstream d445345's bare-string downgrade without asserting that
  calls must bind `x`; `as.double` and `as.logical`
  also gained their missing `...` formal, so `as.numeric` and `as.double`
  (one and the same primitive) no longer carry opposite required-ness. The
  zero-argument primitive audit pins this decision per entry and derives
  it: a pinned primitive that accepts zero-argument calls must not have
  its first formal required.
- Corrected `rlang::env_get_list(default)` optionality and added rlang's five
  exported typed missing-value constants.
- Corrected `default` metadata to SCHEMA.md's syntactic meaning (`default`
  records whether the formal has a default expression): `base::Reduce(init)`,
  `base::exists(frame)`, `base::sample(size)`, `base::source(file)`, and
  `base::source(exprs)` are omittable through `missing()` handling without a
  syntactic default, so they now record `required: false` instead of
  `default: true`.
- Re-audited `vctrs::vec_in` against the vctrs 0.6.5 source and installed
  vctrs 0.7.3: its `na: true` return flag stands. The result is NA-free under the
  default `na_equal = TRUE`, but `na_equal = FALSE` propagates missing
  needles into NA results, and the stub convention records NA possibility
  under any admissible arguments (`base::rank` follows the same rule for
  `na.last = "keep"`).
- Corrected `vctrs::vec_in` return length from `arg0` to `unknown`: the
  result holds one element per size unit, not per R length, so
  `vec_in(df, df)` on a 3-by-2 data frame has length 3 while `arg0` has
  length 2. The length vocabulary has no size-based symbolic length, so
  `unknown` takes the conservative route already used by `vec_slice`.
- Corrected nine stale entries in the base stub's datasets block, found by
  extending the typeshed audit to cover it with correct attribution (base
  namespace or the `datasets` package): `OrchardSprays` and `Theoph` had
  wrong lengths and `OrchardSprays` two phantom factor columns; `rivers`,
  `discoveries`, and `WorldPhones` are double, not integer; `pressure` is
  a 19-row two-column data frame, not a length-19 double vector; the
  `USAccdeaths` entry named a binding that no longer exists (removed in
  favor of the already-correct `USAccDeaths`); `.Options` is a pairlist
  that can hold NA options and is now `opaque`/`na: true`;
  `sunspot.month` is a drifting series whose exact length now only R knows
  (`unknown`).
- Corrected the class order of the nine remaining ordered-factor columns
  that still declared the reversed `["factor", "ordered"]` — R reports
  `class()` as `c("ordered", "factor")`: `CO2$Plant`, `esoph$agegp`,
  `esoph$alcgp`, `esoph$tobgp`, `Loblolly$Seed`, `ChickWeight$Chick`,
  `DNase$Run`, `Indometh$Subject`, and `Orange$Tree` (joining the
  `Theoph$Subject` entry corrected above). `class` is consumer-visible
  vocabulary (ry's `JsonRType.class`) and is now audited (see below).
- Corrected four column-level modes surfaced by the new column checks:
  `npk$N`, `npk$P`, and `npk$K` are integer factors (they also gained the
  missing `class: ["factor"]`, matching sibling `npk$block`), and
  `rock$area` is integer, not double.
- Recorded the full class vectors of the seven nlme-style groupedData
  frames — `CO2`, `Theoph`, `ChickWeight`, `Loblolly`, `DNase`,
  `Indometh`, and `Orange` declared only the `["data.frame"]` tail while
  the stored objects carry
  `c("nfnGroupedData", "nfGroupedData", "groupedData", "data.frame")` —
  and added the two missing special-class declarations surfaced by the
  same sweep: `freeny$y` is `"ts"` and `WorldPhones` is
  `c("matrix", "array")`. Verified ry consumes class vectors
  order-sensitively only through its S3 dispatch walk, which tries every
  class in order, and through membership checks (`contains`,
  `classes_overlap`), so a non-`data.frame` vector head changes no
  consumer outcome while making dispatch-eligible classes truthful.

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
- The function-semantics audit discovers higher-order declarations in installed
  packages and verifies their formal sequences and callback positions. It
  covers 12 base and 27 purrr signatures, and checks structured parameters'
  `default` and `required` metadata against installed formals and reviewed
  omittability conventions.
- Added an allowlisted zero-argument primitive audit for base coercion and
  vector-constructor families. It checks runtime outcomes and formal sequences;
  successful zero-argument calls must have an optional first formal, while
  `as.raw` requires its first argument. An empty reviewed inventory is an error.
- The typeshed audit now covers the base stub's 119-entry `datasets` block,
  attributing each entry to the environment that provides it (base's own
  constants, or the `datasets` package's lazy-data environment, reached
  through `.__NAMESPACE__.$lazydata` with `inherits = FALSE` so the lookup
  cannot resolve foreign names such as `lm` or `read.csv` through the
  namespace's parent chain) before checking existence, mode, length, and
  NA; SCHEMA.md now documents that base's dataset entries name values from
  the default search path rather than base-only bindings. Value checks
  recurse into declared `columns` against the value's elements under the
  same rules, covering the 214 column type objects across the 46
  column-carrying entries. A declared `class` vector must equal the live
  `class()` exactly and in order (an absent field is skipped, since the
  corpus convention declares `class` only when it differs from the
  typeof's implicit class); this check would have caught all nine
  ordered-factor reversals and every groupedData tail truncation. Value
  failures name the entry, a missing
  `mode` or `length` is a named failure instead of an opaque error, and
  the `na` check is one-directional and skips an absent field: `na: true`
  stays a conservative upper bound, and only `na: false` contradicted by
  an actual missing value fails. The rlang assertion witnesses are invoked
  under each assertion's declared `subject_param`, and a check without a
  witness value fails loudly instead of probing `NULL`.

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
