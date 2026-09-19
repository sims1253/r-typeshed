# Oracle packages in CI install order: generator JSON I/O and every
# namespace the inventory oracles and audits load. The single shared
# definition for every consumer — sourced by scripts/render_ci_packages.R
# (pinned installer and drift install lists) and scripts/report_drift.R
# (the drift-report version table) so the two can never disagree on
# coverage; the drift report's former hand-copied vector went stale three
# times during the RColorBrewer..curl inventory batch.
ci_packages <- c(
  "jsonlite", "rlang", "vctrs", "purrr", "dplyr", "ggplot2", "htmltools",
  "shiny", "mirai", "carrier", "R6", "Rcpp", "checkmate", "magrittr",
  "glue", "stringr", "tibble", "lifecycle", "httr", "readr", "scales",
  "RColorBrewer",
  "xml2",
  "MASS",
  "zoo",
  "Matrix",
  "gridExtra",
  "curl"
)
