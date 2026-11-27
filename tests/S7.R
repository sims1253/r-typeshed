#!/usr/bin/env Rscript
# Compare the bundled S7 inventory with the installed CRAN namespace (#138).
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "S7"
version <- "0.2.2"
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)

if (Sys.getenv("RT_TYPESHED_DRIFT") == "") {
  stopifnot(identical(as.character(packageVersion(pkg)), version))
}

doc <- jsonlite::read_json(file.path(root, "stubs", "s7", "S7.json"))
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
  stopifnot(identical(sig$return, opaque))
}

for (name in values) {
  stopifnot(!is.function(getExportedValue(pkg, name)))
  stopifnot(identical(doc$datasets[[name]], opaque))
}

# Preserve curated injects on new_class.
stopifnot(length(doc$functions$new_class$injects) == 1L)
stopifnot(identical(
  unlist(doc$functions$new_class$injects[[1]]$names),
  c("self", "private", "super")
))

# Partial-stub completeness markers on intentionally partial stubs (#138).
for (rel in c("stubs/withr/withr.json", "stubs/rex/rex.json", "stubs/testthat/testthat.json")) {
  partial_doc <- jsonlite::read_json(file.path(root, rel))
  stopifnot(isTRUE(partial_doc$partial))
}

# Local runtime witness: S7 class definition using exported class_double.
Range <- S7::new_class(
  "Range",
  properties = list(start = S7::class_double, end = S7::class_double)
)
r <- Range(start = 1, end = 10)
stopifnot(S7::S7_inherits(r, Range))
stopifnot(identical(r@start, 1), identical(r@end, 10))

cat("S7 exports, values, formals, injects, and partial markers verified.\n")
