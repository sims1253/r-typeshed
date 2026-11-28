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

# Functions that force the original promise do not support injection:
# `expect_match(!!"abc", "abc")` errors in testthat 3.3.2.
stopifnot(is.null(doc$functions$expect_match$injection))
stopifnot(identical(doc$functions$expect_no_error$injection, list(object = "full")))
stopifnot(identical(doc$functions$with_mocked_bindings$injection, list(`...` = "splice")))

# The curated block-evaluation contracts keep their declared shapes.
logical1 <- list(mode = "logical", length = "1", na = FALSE)
curated_params <- list(
  describe = list(list(name = "description", required = TRUE), list(name = "code", required = TRUE)),
  it = list(list(name = "description", required = TRUE), list(name = "code", default = TRUE)),
  test_that = list(list(name = "desc", required = TRUE), list(name = "code", required = TRUE))
)
for (name in names(curated_params)) {
  stopifnot(identical(doc$functions[[name]]$params, curated_params[[name]]))
  stopifnot(identical(doc$functions[[name]]$return, logical1))
}
stopifnot(identical(doc$functions$test_path$params, list("...")))
stopifnot(identical(
  doc$functions$test_path$return,
  list(mode = "character", length = "1", na = FALSE)
))
stopifnot(identical(doc$functions$test_path$source_relative_path_arg, 0L))
