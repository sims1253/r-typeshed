#!/usr/bin/env Rscript
# Compare the bundled covr inventory with the installed CRAN namespace (#139).
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "covr"
version <- "4.0.0"

if (Sys.getenv("RT_TYPESHED_DRIFT") == "") {
  stopifnot(identical(as.character(packageVersion(pkg)), version))
}

doc <- jsonlite::read_json(file.path(root, "stubs", pkg, paste0(pkg, ".json")))
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
}

# Verify formals after `...` are preserved on package_coverage().
pc_params <- vapply(doc$functions$package_coverage$params, function(p) {
  if (is.character(p)) p else p$name
}, character(1))
stopifnot(identical(tail(pc_params, 3L), c("...", "allow_failures", "show_code_output")))
# package_coverage(combine_types = FALSE) returns class "coverages", so do not
# claim unconditional class "coverage".
stopifnot(is.null(doc$functions$package_coverage$return$class))

# Verify curated returns and exported value.
stopifnot(identical(
  doc$functions$in_covr$return,
  list(mode = "logical", length = "1", na = FALSE)
))
stopifnot(identical(
  doc$functions$percent_coverage$return,
  list(mode = "double", length = "1", na = TRUE)
))
for (df_fn in c("tally_coverage", "zero_coverage")) {
  ret <- doc$functions[[df_fn]]$return
  stopifnot(identical(ret$mode, "list"), identical(ret$class, list("data.frame")))
  stopifnot(is.null(ret$columns))
}
stopifnot(identical(
  doc$datasets$colorblind_palette,
  list(mode = "character", length = "3", na = FALSE)
))

# Verify S3 methods match the installed NAMESPACE registrations.
s3_ns <- getNamespaceInfo(pkg, "S3methods")
expected_s3 <- paste0(s3_ns[, 1], ".", s3_ns[, 2])
declared_s3 <- vapply(doc$s3_methods, function(m) {
  paste0(m$generic, ".", m$class)
}, character(1))
stopifnot(setequal(declared_s3, expected_s3))

# Runtime witnesses against live covr 4.0.0.
stopifnot(identical(typeof(covr::in_covr()), "logical"),
          identical(length(covr::in_covr()), 1L),
          !anyNA(covr::in_covr()))
stopifnot(identical(typeof(covr::colorblind_palette), "character"),
          identical(length(covr::colorblind_palette), 3L),
          !anyNA(covr::colorblind_palette))
empty_cov <- structure(list(), class = "coverage")
stopifnot(identical(typeof(covr::percent_coverage(empty_cov)), "double"),
          is.na(covr::percent_coverage(empty_cov)))

cov <- covr::code_coverage("f <- function(x) if (x > 0) 1 else 2", "f(1)")
stopifnot(inherits(cov, "coverage"))
pct <- covr::percent_coverage(cov)
stopifnot(identical(typeof(pct), "double"), identical(length(pct), 1L))
tally <- covr::tally_coverage(cov)
stopifnot(is.data.frame(tally))
zeros <- covr::zero_coverage(cov)
stopifnot(is.data.frame(zeros))

cat("covr exports, datasets, formals, S3 methods, and runtime witnesses verified.\n")
