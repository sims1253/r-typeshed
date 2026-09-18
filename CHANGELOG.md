# Changelog

## [Unreleased]

### Function semantics

- Complete the distribution-family length/missingness sweep in base
  0.0.26: the remaining eight families' density/CDF/quantile entries
  (`dbeta`/`pbeta`/`qbeta`, `dbinom`/`pbinom`/`qbinom`,
  `dchisq`/`pchisq`/`qchisq`, `dexp`/`pexp`/`qexp`, `df`/`pf`/`qf`,
  `dgamma`/`pgamma`/`qgamma`, `dlnorm`/`plnorm`/`qlnorm`, `dt`/`pt`/`qt`)
  receive the same verified correction as the normal, Poisson, and uniform
  families in 0.0.23 — recycling across all numerical value arguments
  (including family shape parameters and `ncp`), any empty value argument
  emptying the result, and missing numerics propagating — so the returns
  drop the false `length: "arg0"` and `na: false` claims for
  `{"mode": "double", "length": "unknown", "na": true}`, with the formal
  lists completed (`log` on the densities; `lower.tail`/`log.p` on the
  CDF/quantile entries). Six previously-missing inventory entries join
  the stub with verified formals and the corrected shape: `qpois`,
  `qbinom`, `dgeom`, `pgeom`, and `qgeom` (all removed from the
  ambient-function list as typed entries), plus `dmultinom`, which is
  verified separately as a scalar density — one value per call regardless
  of input lengths — and therefore declares `length: "1"` with `na: true`.
  The `r*` generators stay untouched: their `n` semantics differ. Pinned
  live by the extended `tests/density_lengths.R`.
- Declare the complex-capable math returns as double/complex unions in
  base 0.0.25: `exp`, `log`, `log10`, `log2`, `sqrt`, `sin`, `cos`, `tan`,
  `asin`, `acos`, `atan`, `sinh`, `cosh`, `tanh`, and `signif` each
  produced complex results for complex input on R 4.6.1 while promising a
  real-only double, so `exp(complex(...))` inferred as double. Each entry
  now returns `{"mode": "union", "members": ["double", "complex"]}`,
  keeping `length: "arg0"` and the existing NA claim; integer inputs
  still give double, hence double stays in the union. `signif` also
  moves from `na: false` to `na: true`: `signif(NA_real_)` is `NA` on
  live R, so the old claim was false. Bare-string params stay
  inference-only; only the return contracts changed. Deliberately
  unchanged: `log1p`, `expm1`, `gamma`, `lgamma`, `digamma`, `trigamma`,
  `floor`, `ceiling`, and `trunc` keep their double returns because
  complex input errors (`unimplemented complex function`) on this R, and
  the `*pi` variants carry no stub entry and reject complex input the
  same way. The `double_or_int` family (`round`, `abs`, `sign`, `sum`,
  `prod`, `mean`, `cumsum`, `cumprod`) is untouched: its declared mode is
  not concrete double and its integer contract needs its own audit.
  Encoded as a union rather than opaque because the pinned consumer
  (ry 0.10.0 at b97cc653) resolves union returns member-wise — probed
  `base::exp(base::complex(real = 1, imaginary = 1))` infers
  `union[double, complex]` instead of the false `double`, with no new
  diagnostics. Pinned by `tests/complex_math.R`, which flips red on any
  reverted return and witnesses the exclusions' live-R errors.

- Correct the base `R.version` family in base 0.0.24: `R.version` is a
  list value, not a function — only `R.Version()` is callable — so the
  phantom zero-argument `functions` entries for `R.version` and its alias
  `version` are removed and `R.Version` gains the conservative signature
  `{"params": [], "return": {"mode": "list", "length": "unknown",
  "na": false}}`. The lowercase spellings stay inventoried where values
  belong (`R.version`, `R.version.string`, and `version` in ambient
  globals; `pi` remains the model: typed in `datasets`, absent from both
  `functions` and the ambient lists).
- Harden the namespace audit against the same class of mistake: entries in
  `functions` that resolve to an existing but non-callable object now fail
  with a contextual `is not callable but declared as a function`
  diagnostic — in the base pass (the `is.null(fn)` formal-audit skip no
  longer stands in for validation) and in the non-base passes (existence
  and export membership additionally establish callability) — while
  legitimate callable re-exports and registered S3 methods still pass.
  Covered by isolated fixtures in `tests/audits.R`: phantom `R.version`
  and `pi` fail, correct `R.Version` passes, a non-base
  exported-value-as-function fails, and a callable re-export plus a
  registered S3 method pass.

- Correct the return lengths and missingness of the normal, Poisson, and
  uniform density/CDF/quantile entries in base 0.0.23: `dnorm`, `dpois`,
  and `dunif` no longer claim `length: "arg0"` with `na: false`, and the
  same correction applies to their verified-identical `pnorm`, `ppois`,
  `punif`, `qnorm`, and `qunif` siblings. Live R on 4.6.1 shows the result
  recycles across all numerical value arguments — `dnorm(0, mean = c(0, 1))`
  has length 2, and any empty value argument empties the result
  (`dnorm(c(0, 1), mean = numeric(0))` has length 0, unlike `paste`, which
  recycles `""` for zero-length inputs) — while `log`, `lower.tail`, and
  `log.p` contribute only their first element, and missing numerics
  propagate (`dnorm(NA_real_)` is `NA`). That any-empty rule is exactly
  what the schema's `recycled_values` cannot express (it zeroes only when
  all values are empty, or — under a `recycle0` control — when one is, and
  these functions take no such control), so the honest encoding is
  `{"mode": "double", "length": "unknown", "na": true}`: it stops the
  false scalar fact ry was resolving from `arg0` without overstating a
  precise recycling rule. The formal lists are completed along the way
  (`log` on the densities; `lower.tail` and `log.p` on the CDF/quantile
  entries). The `rnorm`, `rpois`, and `runif` generators are untouched:
  their `n` semantics differ. The remaining distribution families
  (beta, binomial, chi-squared, exponential, F, gamma, log-normal, t)
  show the same `arg0`/`na: false` shape and are left for follow-up.

- Correct `AIC` and `BIC` in base 0.0.22: complete the public formal
  sequences (`AIC(object, ..., k = 2)`, `BIC(object, ...)`, verified
  against the installed stats generics) and keep the conservative
  opaque, unknown-length, possibly-missing return. Multi-model calls
  return data frames with `df`/`AIC` and `df`/`BIC` columns, so the old
  scalar-double contract was wrong for a common supported API shape and
  turned legitimate `a$AIC` / `b$BIC` column accesses into false RY061
  atomic-vector errors; `BIC` can additionally return `NA` when the
  observation count cannot be established. A data-frame return would
  break the single-model case and overclaim method behavior, so the
  result stays unknown pending a sound overload/dispatch model. Any
  consumer precision must account for S3 methods and unknown dots, not
  just count syntactic arguments.

- Keep `append` results opaque in base 0.0.20: restore the complete
  inference-only formals `x`, `values`, `after` and replace the
  `concat_of_args` return with `{opaque, unknown, na: true}`. The old
  contract folded the insertion-position control into the result, so an
  explicit `after` manufactured a spurious element: `append(1L, 2L,
  after = 0)` claimed `double` of length 3 where R gives an integer of
  length 2, and `if (append(logical(0), TRUE, after = 0L)) 1L` drew a
  false RY001. Precise inference needs a value-contributor consumer rule
  that excludes `after` from mode and length aggregation; until then the
  conservative unknown keeps the checker honest while the genuine
  length-2 error `if (append(FALSE, TRUE)) 1L` stands as the qualifying
  control. Pinned live by `tests/append.R`.
- Declare `ifelse`'s test-template return mode in base 0.0.19:
  `ifelse(test, yes, no)` builds its result from the `test` vector itself
  and overwrites only the selected positions, so the result mode is
  `logical` whenever the test is zero-length or entirely `NA` — even when
  the branches agree on another mode — and otherwise the mode join of the
  branches. Expressed with the new `return_mode` rule
  `{"kind": "test_template", "test": "test", "values": ["yes", "no"]}`,
  the mode-dimension analog of `seq_len`'s `return_length` mechanism, so
  checkers can flag mode collapses (ry's RY106) instead of trusting the
  plain `yes_or_no` join. Mirrors the spec ry has been carrying in its
  local typeshed overlay; a vendor sync from this release is a no-op for
  this entry and lets ry drop the overlay.
- Correct `as.vector`'s return contract in base 0.0.21: it is not an
  identity function, so the `arg0` return becomes opaque/unknown and the
  formals gain the missing `mode` (`as.vector(x, mode)`). `mode` can change
  the storage type (`as.vector(1L, mode = "list")` is a list), factors
  default-coerce to character, and atomic results lose attributes — each
  previously survived as a false input fact (and a false RY061 on
  `v$missing` after a `mode = "list"` coercion). Precise coercion modeling
  — omitted mode, literal supported modes, factor default, attribute
  stripping, dispatch — is future consumer work.

### Schema documentation

- Document the `return_mode` rule in the schema reference:
  `test_template` names the test formal and the value-contributing
  formals of a result seeded from the test's storage, with the `logical`
  collapse on zero-length or all-`NA` tests. Accepted by
  `ry typeshed validate` alongside the `return_length` rules; consumers
  must vendor against a ry that accepts it (ry #472, ahead of 0.10.0 at
  the pinned consumer) before validating this revision's stubs.

## [0.5.1] - 2026-09-15

Data-revision release completing the ry 0.10.0 vendor sync: dynamic-dots
injection metadata for the tibble and vctrs constructors, fixing the false
RY021 that appeared once the tibble inventory resolved previously-unresolved
callees. No schema or inventory changes; consumers on ry 0.10.0 can update
in place.

### Function semantics

- Declare dynamic-dots injection for the tibble constructors (tibble
  0.0.2): `data_frame`, `tibble`, `tibble_row`, and `lst` are quos-based
  constructors whose dots defuse `!!` on the right-hand side as well as
  `!!!` splice and `!!name :=`, so they declare
  `"injection": {"...": "full"}`, matching the existing `dplyr::tibble`
  re-export. `add_row`, `add_column`, and their deprecated alias
  `add_case` declare the same mode: they forward `...` straight into
  `tibble()` (tibble 3.3.1 `R/add.R`), so their dots are quos-defused
  too. `new_tibble` declares `"injection": {"...": "splice"}`: its dots
  go through `pairlist2()` to set named attributes (tibble 3.3.1
  `R/new.R`), so — unlike the quos-based constructors — it splices but
  rejects bare-RHS `!!`. `tribble`, `frame_data`, and `frame_matrix`
  stay undeclared for now: their arguments are formulas, not dynamic
  dots, and no corpus site splices into them. The remaining `...`
  entries in the inventory take ordinary dots: the
  `as_tibble`/`as.tibble`/`as_data_frame`/`glimpse` S3 forwarders, and
  `num`, `char`, `view`, `set_num_opts`, and `set_char_opts`, whose
  dots must be empty (`check_dots_empty()`).
- Add `vctrs::data_frame` with the same contract (vctrs 0.0.2): a
  dynamic-dots constructor with its real control formals (`.size`,
  `.name_repair`, `.error_call`) and `"injection": {"...": "splice"}`
  (its dots go through `list2()`). Pinned live by the
  `audit_function_semantics.R` formals loop and statically by
  `tests/dynamic_dots.R`.
- Without these declarations, a resolvable-but-metadata-less entry is
  worse than no entry: ggplot2's `data_frame0 <- function(...)`
  forwarding stopped inheriting the unresolved-callee injection fallback
  once tibble's inventory resolved the name, and `data_frame0(!!!x)` /
  `data_frame0(!!aes := v)` emitted false RY021 on the splice sites
  (found in the ry 0.10.0 vendor-sync corpus run).

## [0.5.0] - 2026-09-14

Inventory release paired with ry 0.10.0: new export inventories for scales,
readr, checkmate, and httr, plus corrected base length semantics. base 0.0.18
introduces the `longest_arg_or_zero` symbolic length, so consumers must
vendor against a ry that accepts it (ry #459, in 0.10.0) before validating
this release's stubs.

### New stubs

- Add scales 0.0.1 with its complete export inventory from scales 1.4.0:
  210 functions plus the exported `Range`/`DiscreteRange`/`ContinuousRange`
  R6 generators recorded as opaque dataset values. Keep formal lists
  inference-only and returns uniformly `{opaque, unknown, na: true}` per
  the documented inventory convention, resolving `import(scales)`. Part
  of the prioritized backlog in #43.

- Add readr 0.0.1 with its complete export inventory from readr 2.2.0:
  98 functions plus the five exported ChunkCallback-family R6 generators
  recorded as opaque dataset values. Keep formal lists inference-only and
  returns uniformly `{opaque, unknown, na: true}` per the documented
  inventory convention, resolving `import(readr)`. Part of the backlog
  in #43.

- Add checkmate 0.0.1 with its complete 370-function export inventory from
  checkmate 2.3.4. Keep formal lists inference-only and returns uniformly
  `{opaque, unknown, na: true}` per the documented inventory convention,
  resolving `import(checkmate)`. Part of the prioritized backlog in #43.

- Add httr 0.0.1 with its complete export inventory from httr 1.4.9:
  87 functions plus the exported `Token`, `Token1.0`, `Token2.0`, and
  `TokenServiceAccount` R6 generators recorded as opaque dataset values.
  Keep formal lists inference-only and returns uniformly
  `{opaque, unknown, na: true}` per the documented inventory convention,
  resolving `import(httr)`. Part of the prioritized backlog in #43.

- Add jsonlite 0.0.1 with its complete export inventory from jsonlite 2.0.0:
  23 functions plus the five exported `.__T__*` S4 method-table environments
  for base generics, recorded as opaque dataset values. Keep formal lists
  inference-only and returns uniformly `{opaque, unknown, na: true}` per the
  documented inventory convention, resolving `import(jsonlite)` for its 1,692
  CRAN reverse dependencies. Part of the prioritized backlog in #43.

- Add lifecycle 0.0.1 with its complete 16-function export inventory from
  lifecycle 1.0.5. Keep formal lists inference-only and returns uniformly
  `{opaque, unknown, na: true}` per the documented inventory convention,
  resolving `import(lifecycle)`. Part of the prioritized backlog in #43.

- Add tibble 0.0.1 with its complete export inventory from tibble 3.3.1:
  45 functions plus the exported `.__C__tbl_df` S4 class object recorded
  as an opaque dataset value. Keep formal lists inference-only and returns
  uniformly `{opaque, unknown, na: true}` per the documented inventory
  convention, resolving `import(tibble)`. Part of the prioritized backlog
  in #43.

- Add stringr 0.0.1 with its complete 63-function export inventory from
  stringr 1.6.0. Keep formal lists inference-only and returns uniformly
  `{opaque, unknown, na: true}` per the documented inventory convention,
  resolving `import(stringr)` for its 2,259 CRAN reverse dependencies.
  Part of the prioritized backlog in #43.

- Add glue 0.0.1 with its complete 16-function export inventory from
  glue 1.8.1. Keep formal lists inference-only and returns uniformly
  `{opaque, unknown, na: true}` per the documented inventory convention,
  resolving `import(glue)` for its 975 CRAN reverse dependencies. Part
  of the prioritized backlog in #43.

- Add magrittr 0.0.1 with its complete 42-function export inventory from
  magrittr 2.0.5. Keep formal lists inference-only and returns uniformly
  `{opaque, unknown, na: true}` per the documented inventory convention,
  resolving `import(magrittr)` for its 2,255 CRAN reverse dependencies.
  Part of the prioritized backlog in #43.

- Add set6 0.0.1 and dictionar6 0.0.1 with complete export inventories from
  set6 0.2.4 and dictionar6 0.1.3. Record R6 generators as opaque values,
  keep function formals inference-only, and leave return types unknown.

- Add the exported `tags` value in htmltools 0.0.1 and its identical shiny
  re-export in shiny 0.0.2. Describe the lists under namespace/import lookup;
  keep individual tag-constructor results unspecified.

- Add ggplot2 0.0.3 with all 498 exported functions, 145 exported values, and
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

- Correct `file.path` recycling in base 0.0.18: the return length is
  `longest_arg_or_zero`, not `1`. ?file.path produces a path for every
  element only when every argument has positive length; any zero-length
  argument yields an empty character vector (unlike `paste`, which
  recycles `""` for zeros). Removes ry's false RY105 dead-guard claims on
  `length(file.path(...)) > 0` shapes (learnr, blogdown, pkgload).
- Correct `seq_len` in base 0.0.18: the result length is the *value* of
  `length.out` (`1:n`), not the argument's vector length. Expressed with
  the documented `return_length: param_value` mechanism — a literal count
  keeps the exact length, anything dynamic stays unknown — so
  `seq_len(nrow(df))` no longer claims length 1. Removes ry's false RY105
  claims on the brulee shape.

- Correct `mirai::status` in mirai 0.0.2: the formal is `.compute` (character,
  miraiCluster, or NULL), not `.x`, and the return is a named list. `connections`
  (integer) and `daemons` (character URL or `0L`) are always present; `mirai`
  (named integer) and `memory` (named numeric) appear only under a dispatcher, so
  no `columns` schema is declared. Verified against mirai 2.7.2 `R/daemons.R`
  source and runtime on R 4.6.1 with mirai 2.7.1; removes ry's false RY061 on
  `status()$mirai` and `status()$connections`.

- Keep `Find` results unknown in base 0.0.17. No match returns NULL or the
  supplied no-match value; a matching list element can have any length or
  contain missing values. Preserve callback invocation metadata without
  borrowing a scalar result from the input or predicate.

- Keep `Filter` and `Position` results unknown in base 0.0.16. Filtering can
  change length, introduce missing values, or dispatch to an arbitrary subset
  result; `Position` can return any supplied no-match value. Preserve callback
  invocation metadata independently of these result contracts.

- Describe `stats::model.extract` bare component names as quoted symbols in
  base 0.0.15. Keep frame evaluation ordinary and results unknown; do not claim
  arbitrary component expressions are never evaluated by coercion methods.

- Complete `expand.grid` formals and keep its result opaque. Ordinary results
  are data frames with vector columns; input subsetting methods can change the
  construction result through caller-frame effects.

- Complete `confint` formals and keep its dispatched result opaque with unknown
  length and possible missingness. Methods can return lists, and ordinary linear
  model confidence intervals can contain missing entries.

- Keep base `Reduce` and purrr `reduce` results opaque with unknown length and
  possible missingness. Initializers and callbacks can return arbitrary shapes;
  empty and singleton folds can return without invoking a callback.

- Complete `grep` formals and keep its result opaque: `value` selects matching
  strings or indices, long-vector indices can be double, and missing patterns
  can produce missing results. Verify modes, argument matching, and coercion in R.
- Declare full tidy-evaluation injection for `ggplot2::aes` aesthetics and
  `ggplot2::vars` dots, verified with symbol unquoting and list splicing.

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
  Base is revision 0.0.18, purrr is 0.0.4, rlang is 0.1.4, and mirai is
  0.0.2 after the changes below.
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

### Schema documentation

- Document the `longest_arg_or_zero` symbolic length in the schema
  reference: the recycling rule whose result is empty when any argument is
  empty, the ?file.path behavior that distinguishes it from `paste`'s
  `longest_arg`. Accepted by `ry typeshed validate` alongside the existing
  symbolic lengths.

- Document `na` semantics in the schema reference: `true` claims
  NA-capability, `false` claims never-NA, and an absent field declares
  neither way and is not a non-NA guarantee. Record the inventory convention
  of uniform `na: true` on opaque entries with unknown missingness
  (ggplot2, grid, vctrs, set6, dictionar6), reserving `na: false` for values
  known never to be NA such as the htmltools/shiny `tags` lists.

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
