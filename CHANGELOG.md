# Changelog

## [Unreleased]

### New stubs

- Add ggplot2 0.0.2 with all 498 exported functions, 145 exported values, and
  11 lazy datasets, verified against ggplot2 4.0.3. Keep formals inference-only
  and results unknown; preserve the verified `.pt` scalar type and curate
  expression capture for aesthetic mappings, labels, `benchplot`, and rlang re-exports.

- Add grid 0.0.1 with all 248 exported function signatures and `emptyCoords`,
  inventoried from R 4.6.1. Keep returns unknown and formal lists inference-only;
  mark captured drawing expressions without claiming that they are forced.
- Add vctrs 0.0.1 with conservative declarations for `obj_is_list`, `vec_in`,
  `vec_set_union`, `vec_size`, and `vec_slice` used by the hermetic tidyverse audit,
  plus `vec_c`, `vec_cast_common`, `vec_recycle_common`, and `vec_size_common`.

### Function semantics

- Complete `confint` formals and keep its dispatched result opaque with unknown
  length and possible missingness. Methods can return lists, and ordinary linear
  model confidence intervals can contain missing entries.

- Keep base `Reduce` and purrr `reduce` results opaque with unknown length and
  possible missingness. Initializers and callbacks can return arbitrary shapes;
  empty and singleton folds can return without invoking a callback.

- Complete `grep` formals and keep its result opaque: `value` selects matching
  strings or indices, long-vector indices can be double, and missing patterns
  can produce missing results. Verify modes, argument matching, and coercion in R.

- Keep `rapply` returns opaque: its default `how = "unlist"` flattens recursive
  results, while `"replace"` retains input structure and `"list"` returns a list.
  Remove the input-length claim from its simplification metadata; nested leaves
  and callback results can change output length. Runtime controls cover all modes.

- Keep `regmatches` returns opaque because match data and `invert` select
  between a character vector and lists of variable-length character vectors.
  Include the `invert` formal.
- Keep `sort` and `sort.int` returns opaque because `index.return = TRUE` produces a
  list instead of the input vector type. Complete their verified formals.

- Complete `matrix`, `array`, and row/column summary formals so named controls
  such as `byrow`, `dimnames`, `na.rm`, and `dims` can match their R arguments.

- Complete `delayedAssign` and `substitute` environment formals for argument
  matching; preserve their existing capture modes and inference-only parameters.

- Restore completed base higher-order formals and hermetic dependency metadata.
  Base is revision 0.0.13, purrr is 0.0.4, and rlang is 0.1.4 after the changes below.
- Declare sole-argument forcing contracts for base `force`, `identity`,
  `invisible`, `is.function`, `is.null`, `length`, `message`, `stop`, `typeof`,
  and `warning`, plus `rlang::abort`.
- Complete public base higher-order formal lists, including controls after
  `...`, for exact, partial, and positional argument matching. Remove the
  phantom `...` from `Reduce` and cover `Map`'s named-callback call shape.
- Correct purrr higher-order formal lists, seven callback positions, and
  `walk2` callback arity. Supply both callback arguments for `imap`; remove
  unsupported callback-result refinements from `accumulate` and `map_if`.
- Correct typed `map2_*` and `pmap_*` results to atomic vectors. Keep their
  lengths unknown because recycling and component sizes cannot be derived from
  one formal argument. Allow missing results throughout the typed map family.
- Correct constructor formals and distinguish size values from argument lengths.
  Declare typed callback requirements and tidy-evaluation/splicing modes.
- Declare `quoted_expression` evaluation for `base::quote`, `bquote`, and
  `expression`, alongside the existing `alist` declaration, and for
  `rlang::expr` and `quo`. Declare `captures_promise` for `base::substitute`
  and `rlang::exprs`, which can defuse the enclosing caller's supplied promise.
- For `base::delayedAssign`, mark only `value` as `captures_promise`. The
  target name `x` is evaluated to a string; `eval.env` and `assign.env` also evaluate
  normally. These changes cover the quoting helpers with existing stubs;
  they do not add stubs for `evalq`, `local`, or `makeActiveBinding`, or quoting
  metadata to rlang's `sym`, `abort`, `inform`, `new_formula`, or `new_quosure`.
- Make `rlang::quo(expr)` optional: `quo()` returns an empty quosure. Correct
  `rlang::env_get_list(default)` optionality and add five exported typed
  missing-value constants.
- Correct zero-argument declarations for base coercions. `as.raw` requires `x`;
  `as.character`, `as.double`, `as.integer`, `as.logical`, `as.numeric`, and
  `rep` accept omitted `x`, recorded explicitly as `required: false`.
  Add missing `...` formals to `as.double` and `as.logical`; `as.numeric`
  and `as.double` now agree. Keep `data`'s polymorphic return opaque.
- Record syntactic defaults separately from omittability. `Reduce(init)`,
  `exists(frame)`, `sample(size)`, `source(file)`, and `source(exprs)` can be
  omitted through `missing()` handling without having a default expression.
- Keep `base::rep` return length unknown; the retired `x_times` symbolic
  length is no longer supported by the consumer schema.
- Keep `vctrs::vec_in` NA-capable because `na_equal = FALSE` can produce
  missing results. Make its length unknown: it follows vector size rather than
  R length, so a three-row, two-column data frame produces three results.

### Dataset declarations

- Correct lengths and columns for `OrchardSprays` and `Theoph`; remove two
  phantom factor columns from `OrchardSprays`. Declare `rivers`, `discoveries`,
  and `WorldPhones` as double, and `pressure` as a 19-row, two-column data frame.
- Remove the nonexistent `USAccdeaths` alias in favor of `USAccDeaths`.
  Keep `.Options` opaque and NA-capable, and `sunspot.month`'s length unknown.
- Correct ordered-factor class order to `c("ordered", "factor")` for
  `CO2$Plant`, the three ordered `esoph` columns, `Loblolly$Seed`,
  `ChickWeight$Chick`, `DNase$Run`, `Indometh$Subject`, `Orange$Tree`, and
  `Theoph$Subject`.
- Declare `npk$N`, `npk$P`, and `npk$K` as integer factors, and `rock$area`
  as integer rather than double.
- Preserve complete grouped-data class vectors for `CO2`, `Theoph`,
  `ChickWeight`, `Loblolly`, `DNase`, `Indometh`, and `Orange`. Add the missing
  `ts` class for `freeny$y` and `c("matrix", "array")` for `WorldPhones`.
  Class order remains available to the consumer's S3 dispatch walk.

### Generators and update automation

- Prepare draft PRs for named packages or monthly upstream updates, preserving
  curated entries and reporting signature drift. Track packages bundled with
  base R, including grid, through the installed R release rather than CRAN;
  do not try to install those packages separately.
- Generate schema-2 drafts with exported re-exports and unknown returns that
  permit NA. Preserve structured parameters and curated formal order during NSE
  generation so positional callback metadata keeps its meaning.
- Update existing stub files even when directory names differ from package
  names. Reject duplicate package stub paths before writing.
- Keep enclosing parameters required when only a nested function calls
  `missing()` or `nargs()`. Apply the same scope rule in generators and audits.

### Validation and audits

- Inspect dataset missingness only for a non-NA claim, preventing warnings for
  opaque classed environments such as ggproto objects.

- Use ry for schema validation and move duplicate validator fixture coverage
  into the consumer. Resolve stub packages from their headers, including Rcpp
  and S7, without extra CI paths. Replace handwritten audit JSON readers with
  jsonlite.
- Fail the namespace audit on invalid formal names, while distinguishing
  reviewed forwarding. Add tests that prove audit failures are detected.
- Discover higher-order declarations in installed packages and verify formal
  order, callback positions, and structured `default`/`required` metadata
  against installed formals and reviewed omittability. The current inventory
  has 12 base and 25 purrr higher-order declarations.
- Witness quoted-expression and captured-promise behavior in R and rlang,
  including both the forced target name and deferred value of `delayedAssign`.
  Probe assertions through their declared `subject_param`; reject missing
  witness values rather than substituting `NULL`.
- Audit allowlisted zero-argument primitives against runtime behavior and
  formal sequences. A successful zero-argument call requires an optional first
  formal; `as.raw` rejects omission. Fail on an empty reviewed inventory.
- Audit all 119 base dataset declarations against the base namespace or the
  datasets lazy-data environment without inherited lookups. Check existence,
  mode, length, exact class order, and declared NA restrictions, including
  214 column declarations in 46 entries. Diagnose missing mode/length fields
  and named value failures; allow absent class/NA claims and treat `na: true`
  as a conservative upper bound. Document the default-search-path provenance
  of base dataset entries in the schema reference.

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
