# Changelog

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
