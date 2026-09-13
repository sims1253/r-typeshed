#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "tibble"
version <- "3.3.1"
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

# Construction preserves columns and dims, coercion keeps the row count.
stopifnot(identical(tibble::is_tibble(tibble::tibble(x = 1:2)), TRUE))
stopifnot(identical(tibble::tibble(x = 1:2)$x, 1:2))
m <- matrix(1:4, ncol = 2, dimnames = list(NULL, c("a", "b")))
stopifnot(identical(nrow(tibble::as_tibble(m)), 2L))

cat("tibble exports, formals, and tibble construction verified.\n")
