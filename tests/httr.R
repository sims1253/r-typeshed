#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "httr"
version <- "1.4.8"
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

# R6 generators are exported objects; their $new members construct tokens.
stopifnot(is.environment(httr::Token), is.function(httr::Token$new))
stopifnot(is.environment(httr::Token2.0), is.function(httr::Token2.0$new))

# URL parsing, modification, and status mapping are pure computations.
url <- httr::parse_url("http://example.com/path?a=1")
stopifnot(identical(class(url), "url"))
stopifnot(identical(url$scheme, "http"), identical(url$hostname, "example.com"))
stopifnot(identical(url$path, "path"), identical(url$port, NULL))
stopifnot(identical(url$query, list(a = "1")))
stopifnot(identical(httr::modify_url("http://example.com/path", path = "x"),
                    "http://example.com/x"))
stopifnot(identical(httr::http_status(200L)$category, "Success"))
stopifnot(identical(httr::http_status(404L)$category, "Client error"))

cat("httr exports, formals, and URL helpers verified.\n")
