#!/usr/bin/env Rscript

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
source(file.path(root, "scripts", "update_typeshed.R"))
stopifnot(valid_package("Rcpp"), valid_package("data.table"))
for (bad in c("", "../base", "-e", "pkg; touch x", "pkg/name", "pkg\nother", "a.")) stopifnot(!valid_package(bad))
stopifnot(identical(changed_packages(list(a = "1.0", b = "2.0"), list(a = "1.0", b = "2.1", c = "1.0")), c("b", "c")))
stopifnot(!length(changed_packages(list(a = "1.0"), list(a = "1.0"))))
# CRAN metadata spells some versions with dashes (zoo 1.9-0, MASS 7.3-66,
# Matrix 1.7-6, RColorBrewer 1.1-3) and upstream-versions.json mixes
# spellings (dot-normalized at curation, CRAN's canonical string after
# publish); a spelling difference must not register as a change, but a
# genuinely different version still must.
stopifnot(same_version("1.9.0", "1.9-0"), !same_version("1.9.0", "1.9-1"))
stopifnot(!same_version(NULL, "1.9.0"), !same_version("1.9.0", NA_character_))
stopifnot(same_version("draft", "draft"), !same_version("draft", "other"))
stopifnot(!length(changed_packages(list(zoo = "1.9.0", MASS = "7.3.66", Matrix = "1.7.6", RColorBrewer = "1.1.3"), list(zoo = "1.9-0", MASS = "7.3-66", Matrix = "1.7-6", RColorBrewer = "1.1-3"))))
stopifnot(identical(changed_packages(list(zoo = "1.9.0"), list(zoo = "1.9-1")), "zoo"))
stopifnot(identical(bump_version("0.0.9"), "0.0.10"), identical(bump_version("draft"), "draft"))
bundled <- base_package_versions()
stopifnot(identical(bundled$base, as.character(getRversion())), identical(bundled$grid, as.character(packageVersion("grid"))))
stopifnot(!("survival" %in% names(bundled))) # Recommended packages still track CRAN.
curated <- list(version = "0.0.1", functions = list(kept = list(params = list(list(name = "x", required = TRUE)), return = list(mode = "integer", length = "1"), higher_order = list(callback_position = 0L))))
draft <- list(functions = list(kept = list(params = list("renamed")), added = list(params = list("x"))))
merged <- merge_draft(curated, draft)
stopifnot(identical(merged$functions$kept, curated$functions$kept), identical(merged$functions$added, draft$functions$added))
stopifnot(identical(signature_changes(curated, draft), "kept"))
stopifnot(identical(merge_draft(curated, list(functions = list())), curated))
draft$functions$kept$params <- list("x")
stopifnot(identical(signature_changes(curated, draft), "kept"))

# An archived package or unavailable secondary repository must not block CRAN updates.
local({
  available.packages <- function(repos, type) {
    if (grepl("r-universe", repos, fixed = TRUE)) stop("repository unavailable")
    matrix("1.2.3", nrow = 1L, dimnames = list("dplyr", "Version"))
  }
  lookup <- upstream_versions
  environment(lookup) <- environment()
  base_package_versions <- function() list(base = "4.6.1", grid = "4.6.1")
  warnings <- character()
  versions <- withCallingHandlers(lookup(c("archived", "cmdstanr", "dplyr", "base", "grid")), warning = function(w) {
    warnings <<- c(warnings, conditionMessage(w))
    invokeRestart("muffleWarning")
  })
  stopifnot(identical(versions, list(dplyr = "1.2.3", base = "4.6.1", grid = "4.6.1")), any(grepl("archived", warnings)), any(grepl("cmdstanr", warnings)))
  stopifnot(!any(grepl("Skipping (base|grid)", warnings)))
  upstream_versions <- lookup
  plan <- main
  environment(plan) <- environment()
  for (package in c("base", "grid", "dplyr")) {
    output <- capture.output(plan(c("plan", package)))
    entry <- jsonlite::fromJSON(paste(output, collapse = "\n"), simplifyVector = FALSE)[[1]]
    stopifnot(identical(entry$package, package), identical(entry$bundled, package != "dplyr"))
    stopifnot(identical(entry$version, versions[[package]]))
  }
})

main <- function() {
  work <- tempfile("typeshed-update-test-")
  dir.create(file.path(work, "scripts"), recursive = TRUE)
  on.exit(unlink(work, recursive = TRUE))
  file.copy(list.files(file.path(root, "scripts"), full.names = TRUE), file.path(work, "scripts"))
  report <- file.path(work, "review.md")
  for (package in c("Rcpp", "S7")) {
    expected <- file.path(root, "stubs", tolower(package), paste0(package, ".json"))
    stopifnot(identical(stub_path(package, root), expected))
  }
  stopifnot(inherits(try(prepare_package("dplyr", work, report, "0.0.0"), silent = TRUE), "try-error"))
  # The prepare assert sees the dash-spelled CRAN version from the plan job
  # against the dot-normalized installed form; same_version must accept the
  # matching spelling and still stop on a genuinely different version.
  installed <- as.character(packageVersion("dplyr"))
  dashed <- sub("[.]([0-9]+)$", "-\\1", installed)
  newer <- sub("[.]([0-9]+)$", paste0("-", as.integer(sub(".*[.]", "", installed)) + 1L), installed)
  stopifnot(installed != dashed, dashed != newer, identical(package_version(installed), package_version(dashed)))
  prepare_package("dplyr", work, report, dashed)
  stopifnot(inherits(try(prepare_package("dplyr", work, report, newer), silent = TRUE), "try-error"))
  prepare_package("dplyr", work, report)
  path <- file.path(work, "stubs", "dplyr", "dplyr.json")
  generated <- jsonlite::read_json(path)
  stopifnot(identical(generated$version, "0.0.1"), identical(generated$package, "dplyr"))
  stopifnot(identical(generated$functions$mutate$eval[["..."]], "data_mask"))
  # Existing directory names need not match the package name.
  stopifnot(file.rename(dirname(path), file.path(work, "stubs", "DPLYR")))
  path <- file.path(work, "stubs", "DPLYR", "dplyr.json")
  # A changed, curated function must survive a fresh upstream draft exactly.
  generated$functions$mutate$params <- list(list(name = "curated", required = TRUE))
  generated$functions$mutate$return <- list(mode = "list", length = "arg0")
  generated$functions$mutate$higher_order <- list(callback_position = 0L)
  generated$functions$retained_private <- list(params = list("x"), return = "arg0")
  generated$functions$filter <- NULL
  write_json(generated, path)
  prepare_package("dplyr", work, report)
  stopifnot(!dir.exists(file.path(work, "stubs", "dplyr")))
  updated <- jsonlite::read_json(path)
  stopifnot(identical(updated$functions$mutate, generated$functions$mutate))
  stopifnot(identical(updated$functions$retained_private, generated$functions$retained_private))
  stopifnot(!is.null(updated$functions$filter), identical(updated$version, "0.0.2"))
  notes <- paste(readLines(report), collapse = "\n")
  stopifnot(grepl("curated", notes, fixed = TRUE), grepl("retained_private", notes, fixed = TRUE))
  stopifnot(identical(jsonlite::read_json(file.path(work, "upstream-versions.json"))$dplyr, as.character(packageVersion("dplyr"))))
  before <- readBin(path, "raw", n = file.info(path)$size)
  prepare_package("dplyr", work, report)
  stopifnot(identical(readBin(path, "raw", n = file.info(path)$size), before))
  cat("Update planning, new-package generation, curation preservation, and idempotence verified.\n")
}
main()
