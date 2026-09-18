#!/usr/bin/env Rscript
# Report the drift job's installed versions against the recorded reference
# pins: a compact table showing exactly which packages moved upstream.
#
# Usage (from the repository root):
#   Rscript --vanilla scripts/report_drift.R '<drift-json>' > drift-report.md
#
# The JSON argument is the `drift-json` output of scripts/render_ci_packages.R.

args <- commandArgs(trailingOnly = TRUE)
if (!length(args)) stop("Usage: report_drift.R '<drift-json>'")
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required")

pins <- jsonlite::fromJSON(args[[1L]], simplifyVector = FALSE)
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
