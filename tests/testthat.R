#!/usr/bin/env Rscript
# Compare the bundled testthat inventory with the installed CRAN namespace.
# ry attaches testthat to every package test file, so a partial stub would
# leave the search path open in all of them (sims1253/ry#944).
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "testthat"
version <- "3.3.2"
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)
curated <- c("describe", "it", "test_path", "test_that")

if (Sys.getenv("RT_TYPESHED_DRIFT") == "") {
  stopifnot(identical(as.character(packageVersion(pkg)), version))
}

doc <- jsonlite::read_json(file.path(root, "stubs", "testthat", "testthat.json"))
stopifnot(!isTRUE(doc$partial))

exports <- getNamespaceExports(pkg)
functions <- exports[vapply(exports, function(name) {
  is.function(getExportedValue(pkg, name))
}, logical(1))]
values <- setdiff(exports, functions)

stopifnot(setequal(names(doc$functions), functions))
stopifnot(setequal(names(doc$datasets), values))

for (name in functions) {
  sig <- doc$functions[[name]]
  param_names <- vapply(sig$params, function(p) {
    if (is.character(p)) p else p$name
  }, character(1))
  expected_params <- names(formals(getExportedValue(pkg, name)))
  if (is.null(expected_params)) expected_params <- character(0)
  stopifnot(identical(param_names, expected_params))
  if (!name %in% curated) {
    # Inventory entries stay inference-only: plain names, no arity claims.
    stopifnot(all(vapply(sig$params, is.character, logical(1))))
    stopifnot(identical(sig$return, opaque))
  }
}

for (name in values) {
  stopifnot(!is.function(getExportedValue(pkg, name)))
  stopifnot(identical(doc$datasets[[name]], opaque))
}

# Expectations quasiquote `object`/`expected` through quasi_label(enquo()),
# so `!!` there is injection, not double negation.
stopifnot(identical(doc$functions$expect_equal$injection, list(object = "full", expected = "full")))
stopifnot(identical(doc$functions$expect_true$injection, list(object = "full")))

# The curated block-evaluation contracts keep their declared shapes.
stopifnot(identical(doc$functions$test_that$return$mode, "logical"))
stopifnot(identical(doc$functions$test_path$source_relative_path_arg, 0L))
