#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "jsonlite"
version <- "2.0.0"
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

# Serialization round-trips are pure string checks; toJSON/minify return
# class-"json" strings, so compare the underlying character data.
stopifnot(identical(as.character(jsonlite::minify('{ "a" : 1 }')), '{"a":1}'))
stopifnot(identical(as.character(jsonlite::toJSON(1:2)), "[1,2]"))
stopifnot(identical(class(jsonlite::toJSON(list(a = 1), auto_unbox = TRUE)), "json"))

cat("jsonlite exports, formals, and serialization behavior verified.\n")
