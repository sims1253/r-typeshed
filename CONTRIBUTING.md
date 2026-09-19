# Contributing to r-typeshed

Stubs describe package behavior for [ry](https://github.com/sims1253/ry).
Use the [schema reference](schema/SCHEMA.md) when editing them and check
[consumer compatibility](README.md#versioning) before validation.

## Adding a package

Run commands from the repository root. Install `jsonlite` and the R package
you want to describe before running either generator.

1. Create `stubs/<package>/` and save the generator's JSON output to
   `stubs/<package>/<package>.json`. The generator writes to standard output;
   it does not save a file. For example, for a new `digest` stub:

   ```bash
   mkdir -p stubs/digest
   Rscript --vanilla scripts/gen_typeshed.R digest > stubs/digest/digest.json
   ```

   For an existing package, use [Package update drafts](#package-update-drafts)
   to preserve its curated entries.
2. For packages that document NSE per argument with `<data-masking>` /
   `<tidy-select>` Rd markers (tidyverse style), run
   `Rscript --vanilla scripts/gen_nse_metadata.R <package>` to derive the `eval`
   metadata from the installed package.
3. Hand-curate return types, remaining evaluation modes, `injects`,
   `injection`, and `scope_effect` entries, aliases, datasets, and methods.
4. Run the [local checks](#local-checks).
5. Open a pull request containing `stubs/<package>/<package>.json`.

The generators produce drafts for review. Replace the generated `"draft"`
version with a stub data revision before submitting it. Record each stub data
change under `[Unreleased]` in `CHANGELOG.md`. NSE generation writes
to the existing stub file, even when its directory uses different capitalization,
and preserves curated evaluation metadata and parameter order. New parameters
are appended so positional metadata keeps its meaning. Review the order against
the installed package before submitting changes. The generator stops if multiple
files match the package name.

## Local checks

Install the same R dependencies used by CI:

```r
install.packages(c("jsonlite", "rlang", "vctrs", "purrr", "dplyr", "mirai", "carrier"))
```

Run the regression checks and audits:

```bash
Rscript --vanilla tests/audits.R
Rscript --vanilla tests/base_lengths.R
Rscript --vanilla tests/ifelse_mode.R
Rscript --vanilla tests/append.R
Rscript --vanilla tests/as_vector.R
Rscript --vanilla tests/aic_bic.R
Rscript --vanilla tests/density_lengths.R
Rscript --vanilla tests/complex_math.R
Rscript --vanilla tests/dynamic_dots.R
Rscript --vanilla tests/grid.R
Rscript --vanilla tests/regmatches.R
Rscript --vanilla tests/sort_int.R
Rscript --vanilla tests/ggplot2.R
Rscript --vanilla tests/rapply.R
Rscript --vanilla tests/grep.R
Rscript --vanilla tests/folds.R
Rscript --vanilla tests/confint.R
Rscript --vanilla tests/expand_grid.R
Rscript --vanilla tests/html_tags.R
Rscript --vanilla tests/model_extract.R
Rscript --vanilla tests/filter_position.R
Rscript --vanilla tests/find.R
Rscript --vanilla tests/mirai.R
Rscript --vanilla tests/set6.R
Rscript --vanilla tests/magrittr.R
Rscript --vanilla tests/glue.R
Rscript --vanilla tests/stringr.R
Rscript --vanilla tests/tibble.R
Rscript --vanilla tests/lifecycle.R
Rscript --vanilla tests/jsonlite.R
Rscript --vanilla tests/httr.R
Rscript --vanilla tests/checkmate.R
Rscript --vanilla tests/readr.R
Rscript --vanilla tests/scales.R
Rscript --vanilla tests/RColorBrewer.R
Rscript --vanilla tests/xml2.R
Rscript --vanilla tests/MASS.R
Rscript --vanilla tests/zoo.R
Rscript --vanilla tests/Matrix.R
Rscript --vanilla tests/gridExtra.R
Rscript --vanilla tests/curl.R
Rscript --vanilla tests/generators.R
Rscript --vanilla tests/updates.R
Rscript --vanilla tests/pinned_versions.R
Rscript --vanilla scripts/gen_standard_globals.R --check
Rscript --vanilla scripts/audit_zero_arg_primitives.R
Rscript --vanilla scripts/audit_typeshed.R
Rscript --vanilla scripts/audit_function_semantics.R
ry typeshed validate stubs/
```

Run the inference gate (needs a pinned-ry build; see below):

```bash
scripts/inference_gate.sh <ry-binary> stubs/
scripts/inference_mutation_test.sh <ry-binary>
```

The namespace audit skips packages that are not installed. Install the package
you changed to check its declarations. Schema validation checks every stub,
but does not verify its behavior against R.

## Inference gate

Schema validation agrees on JSON vocabulary; it cannot tell whether the
checker reads a declaration the way R behaves. The `inference` CI job
closes that gap for a bounded, representative corpus: it builds the pinned
ry from `.github/ry-consumer`, runs `tests/inference/` through the
checker's inference with the candidate stubs, and asserts inferred types
and diagnostic identities — not just counts.

- `tests/inference/*-clean.R` must check with zero diagnostics;
  `*-diag.R` must produce exactly the diagnostics in
  `tests/inference/expectations.json` (rule code, severity, line, column).
- `tests/inference/dump-*.R` pin inferred binding types in
  `tests/inference/dump-expectations.json`. `dump-types` has no
  `--typeshed` flag at the pin, so the gate stages the fixtures in a
  scratch project whose `ry.toml` points at the candidate stubs.
- The corpus covers the semantic fixes one family per fixture pair:
  `append` (PR #68), `as.vector` (PR #67), `AIC` (PR #69), density
  lengths (PR #70), the `R.Version` callable (PR #71), and the
  complex-math union returns (PR #73) — each false fact that used to be
  inferred must now be absent, with a neighboring true-error control that
  must still fire. Two known-safe fixtures, one higher-order
  (`vapply` FUN.VALUE templating) case, and one eval/injection
  (`data()` unknown bindings) pair round it out.
- `scripts/inference_mutation_test.sh` is the self-test: it copies
  `stubs/`, applies a deliberate schema-valid semantic mutation (for
  example reverting `dnorm`'s length to `"arg0"`), and asserts the gate
  fails with useful expected/actual output. A green gate run means
  little without it — run the self-test after touching the corpus.
- The gate proves the candidate stubs supplied each fact two ways: the
  `--typeshed` override (plus the `ry.toml` override for `dump-types`)
  selects the candidate tree, and a stale-embedded cross-check re-runs
  the dump fixtures with no override, where the release binary's older
  embedded snapshot must still show the pre-fix facts. If a future pin
  refreshes the embedded catalog past these fixes, that cross-check
  degrades to a warning rather than failing the job.

How a schema change lands in ry first: the checker and its schema
vocabulary live in the ry repository, so new return kinds, metadata, or
inference rules are implemented and released there. This repo then
adopts the new vocabulary in stubs, and the pin in
`.github/ry-consumer` advances to the ry revision whose release notes
cover the change. The inference corpus only uses vocabulary the pinned
ry understands; when the pin advances, extend the fixtures to the newly
supported semantics and refresh any stale-embedded expectations.

Intentionally uncovered: precise recycling rules the schema cannot
express (densities stay `unknown` rather than claiming a rule), S3
dispatch precision beyond the conservative opaque returns, overloads
that depend on argument counts (multi-model `AIC`), and the remaining
distribution families noted in PR #70. The corpus is representative by
design — a changed stub with no fixture is a changed stub with no net.

The set6 and dictionar6 inventories use archived CRAN releases. Install `R6`,
`Rcpp`, and `checkmate`, then run `Rscript --vanilla tests/install_set6_deps.R`
before their runtime checks. The installer uses ooplah 0.2.0, dictionar6 0.1.3,
and set6 0.2.4, matching the package versions in the corpus investigation.

## Package update drafts

In Actions, run **Prepare typeshed updates** and enter a package name. This
works for a new package or one with existing stubs. From the command line:

```bash
gh workflow run update-typeshed.yml --repo sims1253/r-typeshed -f package=dplyr
```

The same workflow checks upstream versions on the first day of each month.
An empty package input runs that check immediately. CRAN supplies package
releases; `cmdstanr` uses Stan's R-universe repository. Base-priority packages
such as `base` and `grid` follow the R installation used by CI and do not need
a separate package install.

Each selected package gets a draft PR. The generators add missing exported
functions with unknown return types and derive documented NSE metadata.
Existing curated entries stay intact, including positional callback metadata.
Formal-name and declared-requiredness changes, and entries no longer exported,
are listed for review. Return behavior and default-value changes still need
manual inspection. Base updates refresh only its generated inventory.

The PR includes schema-validation and R-audit results, including failures that
need cleanup. An open automation draft is left alone so reruns cannot overwrite
reviewer edits. Approve any waiting CI workflows in GitHub, curate the draft,
and mark it ready for review; this workflow never merges its own PRs.

`upstream-versions.json` tracks observed package releases separately from stub
data revisions. Its initial baseline records versions observed on 2026-09-06;
it does not claim that every curated signature was verified against those
versions. Subsequent draft PRs record the installed version used to generate
their updates. A release with no generated code changes can therefore produce
a version-only PR with review notes.

## Generated base inventory

`stubs/base/base.json`'s ambient symbol split and dataset inventory are
generated by `scripts/gen_standard_globals.R` from a local R
installation; CI runs its `--check` mode so the file cannot go stale
silently.
