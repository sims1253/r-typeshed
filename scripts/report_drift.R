#!/usr/bin/env Rscript
# Report the drift job's installed versions against the recorded reference
# pins: a compact table showing exactly which packages moved upstream.
#
# Usage (from the repository root):
#   Rscript --vanilla scripts/report_drift.R > drift-report.md
#
# Reads the recorded reference pins from upstream-versions.json and the
# installed versions from the live library. Runs after the drift job's
# package install step, so jsonlite is available.

if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required")
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
recorded <- jsonlite::read_json(file.path(root, "upstream-versions.json"))
# Oracle packages in CI install order: the single shared definition in
# scripts/ci_packages.R, so this table's coverage cannot drift from the
# installer lists rendered by scripts/render_ci_packages.R.
source(file.path(root, "scripts", "ci_packages.R"))
pins <- lapply(ci_packages, function(package) list(package = package, pinned = recorded[[package]]))
lines <- c(
  "## Upstream drift report",
  "",
  "Installed latest-CRAN versions against the recorded reference pins.",
  "Version-only movement is expected noise; probe failures below point at",
  "true export, formal, value-shape, or semantic changes worth reviewing.",
  "",
  "| package | reference | installed | changed |",
  "| --- | --- | --- | --- |"
)
for (entry in pins) {
  package <- entry$package
  pinned <- entry$pinned
  installed <- as.character(tryCatch(packageVersion(package), error = function(e) NA))
  changed <- if (is.na(installed)) "missing" else if (identical(installed, pinned)) "no" else "yes"
  lines <- c(lines, sprintf("| %s | %s | %s | %s |", package, pinned, installed, changed))
}
lines <- c(lines, "", "## Oracle probes against latest upstream", "")
cat(lines, sep = "\n")
