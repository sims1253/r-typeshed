#!/usr/bin/env Rscript
# Compare the bundled inventory and attach list with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "tidyverse"
version <- "2.0.0"
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)

stopifnot(identical(as.character(packageVersion(pkg)), version))
doc <- jsonlite::read_json(file.path(root, "stubs", pkg, paste0(pkg, ".json")))
exports <- getNamespaceExports(pkg)
stopifnot(setequal(names(doc$functions), exports))
for (name in exports) {
  sig <- doc$functions[[name]]
  stopifnot(identical(sig$params, as.list(names(formals(getExportedValue(pkg, name))))))
  stopifnot(identical(sig$return, opaque))
}

# `library(tidyverse)` attaches exactly the core packages, in this order.
stopifnot(identical(unlist(doc$attaches), getFromNamespace("core", pkg)))

cat("tidyverse exports, formals, and attached core packages verified.\n")
