#!/usr/bin/env Rscript
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base_doc <- jsonlite::read_json(file.path(root, "stubs/base/base.json"))
purrr_doc <- jsonlite::read_json(file.path(root, "stubs/purrr/purrr.json"))
for (spec in list(base_doc$functions$Reduce, purrr_doc$functions$reduce)) {
  stopifnot(identical(spec$return, list(mode = "opaque", length = "unknown", na = TRUE)))
  stopifnot(is.null(spec$higher_order$result$source_arg))
  stopifnot(identical(unlist(spec$higher_order$callback_args), "accumulator_and_element"))
}
param_names <- function(params) vapply(params, function(x) if (is.character(x)) x else x$name, character(1))
stopifnot(identical(param_names(base_doc$functions$Reduce$params), names(formals(base::Reduce))))
stopifnot(identical(param_names(purrr_doc$functions$reduce$params), names(formals(purrr::reduce))))

# Empty and singleton folds can return without invoking the callback.
never <- function(...) stop("callback must not run")
initial <- list(1L, NA_integer_)
stopifnot(identical(Reduce(never, character(), init = initial), initial))
stopifnot(identical(Reduce(never, character()), NULL))
stopifnot(identical(Reduce(never, "input"), "input"))
stopifnot(identical(purrr::reduce(character(), never, .init = initial), initial))
stopifnot(identical(purrr::reduce("input", never), "input"))
stopifnot(inherits(tryCatch(purrr::reduce(character(), never), error = identity), "error"))

# Neither the input nor the initializer fixes the final shape or missingness.
for (fold in list(
  function(f) Reduce(f, 1:3, init = FALSE),
  function(f) purrr::reduce(1:3, f, .init = FALSE)
)) {
  stopifnot(identical(fold(function(a, b) c("changed", "shape")), c("changed", "shape")))
  stopifnot(identical(fold(function(a, b) list(NA, NA)), list(NA, NA)))
  stopifnot(identical(fold(function(a, b) NULL), NULL))
  stopifnot(identical(fold(function(a, b) NA), NA))
}
stopifnot(identical(Reduce(never, integer(), NA), NA))
stopifnot(identical(purrr::reduce(integer(), never, .init = NA), NA))
stopifnot(identical(Reduce(function(a, b) TRUE, c("a", "b"), accumulate = TRUE), c("a", "TRUE")))
stopifnot(identical(Reduce(function(a, b) TRUE, 1:2, init = FALSE, accumulate = TRUE, simplify = FALSE), list(FALSE, TRUE, TRUE)))
stopifnot(identical(purrr::reduce(1:3, function(a, b) rlang::done(initial), .init = FALSE), initial))
cat("Fold initializer, callback, accumulation, and missing-result controls verified.\n")
