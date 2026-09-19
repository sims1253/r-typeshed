#!/usr/bin/env Rscript
# Render CI package specs from the single version source, upstream-versions.json.
#
# Usage (from the repository root):
#   Rscript --vanilla scripts/render_ci_packages.R pinned   # reference oracle (pkg@version)
#   Rscript --vanilla scripts/render_ci_packages.R drift    # upstream drift (any::pkg)
#
# `pinned` renders the exact reference versions recorded in
# upstream-versions.json (`pkg@version`, pak's documented pin form --
# `any::` cannot carry a version constraint) so re-running a fixed catalog
# revision selects the same packages. `drift` renders unversioned `any::`
# specs so the drift job always probes latest CRAN. Both read the same
# install list in the same order, so the two jobs can only disagree on
# versions, never on coverage. Neither mode requires any R package: the
# drift job renders its list before jsonlite is installed. Transitive
# dependencies are resolved by setup-r-dependencies in CI and are
# deliberately not pinned here: only the oracle packages are asserted
# against installed versions, so recording transitives would add churn
# without strengthening provenance.
#
# The rendered list is also consumed by tests/pinned_versions.R, which runs
# the same functions against mocked version metadata so the version source,
# the installer, the oracle expectations, and the update planner cannot
# silently disagree.

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[[1L]] else "pinned"

# Oracle packages in CI install order: generator JSON I/O and every
# namespace the inventory oracles and audits load.
ci_packages <- c(
  "jsonlite", "rlang", "vctrs", "purrr", "dplyr", "ggplot2", "htmltools",
  "shiny", "mirai", "carrier", "R6", "Rcpp", "checkmate", "magrittr",
  "glue", "stringr", "tibble", "lifecycle", "httr", "readr", "scales",
  "RColorBrewer",
  "xml2"
)

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))

read_pins <- function(path = file.path(root, "upstream-versions.json")) {
  if (requireNamespace("jsonlite", quietly = TRUE)) {
    return(jsonlite::read_json(path))
  }
  # Bootstrap fallback: upstream-versions.json is a flat name -> version
  # string map, so CI steps that run before any package is installed can
  # read it without jsonlite.
  lines <- readLines(path, warn = FALSE)
  m <- regmatches(lines, regexec('^\\s*"([^"]+)"\\s*:\\s*"([^"]+)"\\s*,?\\s*$', lines))
  m <- m[vapply(m, length, integer(1)) == 3L]
  setNames(vapply(m, `[[`, character(1), 3L), vapply(m, `[[`, character(1), 2L))
}

render_pinned <- function(pins) {
  missing <- setdiff(ci_packages, names(pins))
  if (length(missing)) {
    stop(sprintf("upstream-versions.json lacks CI packages: %s", paste(missing, collapse = ", ")))
  }
  vapply(ci_packages, function(package) {
    version <- pins[[package]]
    if (!is.character(version) || length(version) != 1L || is.na(version) || !nzchar(version)) {
      stop(sprintf("invalid recorded version for %s", package))
    }
    sprintf("%s@%s", package, version)
  }, character(1))
}

render_drift <- function() {
  sprintf("any::%s", ci_packages)
}

if (sys.nframe() == 0L) {
  if (mode == "pinned") {
    cat(render_pinned(read_pins()), sep = "\n")
  } else if (mode == "drift") {
    cat(render_drift(), sep = "\n")
  } else {
    stop("Usage: render_ci_packages.R [pinned|drift]")
  }
}
