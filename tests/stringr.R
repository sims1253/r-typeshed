#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "stringr"
version <- "1.6.0"
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)

stopifnot(identical(as.character(packageVersion(pkg)), version))
doc <- jsonlite::read_json(file.path(root, "stubs", pkg, paste0(pkg, ".json")))
exports <- getNamespaceExports(pkg)
functions <- exports[vapply(exports, function(name) {
  is.function(getExportedValue(pkg, name))
}, logical(1))]
values <- setdiff(exports, functions)
stopifnot(setequal(names(doc$functions), functions))
stopifnot(setequal(names(doc$datasets), values))
for (name in functions) {
  sig <- doc$functions[[name]]
  stopifnot(identical(sig$params, as.list(names(formals(getExportedValue(pkg, name))))))
  stopifnot(identical(sig$return, opaque))
}
for (name in values) {
  stopifnot(!is.function(getExportedValue(pkg, name)))
  stopifnot(identical(doc$datasets[[name]], opaque))
}

# Lengths, concatenation, detection, and case mapping.
stopifnot(identical(stringr::str_length("ab"), 2L))
stopifnot(identical(stringr::str_c("a", "b"), "ab"))
stopifnot(identical(stringr::str_detect("abc", "b"), TRUE))
stopifnot(identical(stringr::str_to_upper("a"), "A"))

cat("stringr exports, formals, and string behavior verified.\n")
