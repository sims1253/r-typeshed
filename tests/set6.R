#!/usr/bin/env Rscript
# Compare the bundled inventories with the archived CRAN namespaces.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
versions <- c(set6 = "0.2.4", dictionar6 = "0.1.3")
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)

for (pkg in names(versions)) {
  stopifnot(identical(as.character(packageVersion(pkg)), versions[[pkg]]))
  doc <- jsonlite::read_json(file.path(root, "stubs", pkg, paste0(pkg, ".json")))
  exports <- getNamespaceExports(pkg)
  functions <- exports[vapply(exports, function(name) {
    is.function(getExportedValue(pkg, name))
  }, logical(1))]
  stopifnot(setequal(names(doc$functions), functions))
  stopifnot(setequal(names(doc$datasets), setdiff(exports, functions)))
  for (name in functions) {
    sig <- doc$functions[[name]]
    stopifnot(identical(sig$params, as.list(names(formals(getExportedValue(pkg, name))))))
    stopifnot(identical(sig$return, opaque))
  }
  for (name in names(doc$datasets)) {
    stopifnot(!is.function(getExportedValue(pkg, name)))
    stopifnot(identical(doc$datasets[[name]], opaque))
  }
}

# R6 generators are exported objects; their $new members construct instances.
stopifnot(is.environment(set6::Set), is.function(set6::Set$new))
stopifnot(inherits(set6::Set$new(1L), "Set"))
stopifnot(is.environment(dictionar6::Dictionary), is.function(dictionar6::Dictionary$new))
stopifnot(inherits(dictionar6::dct(x = list(a = 1L)), "Dictionary"))
error <- tryCatch(getExportedValue("set6", "Reaals"), error = identity)
stopifnot(inherits(error, "error"))

cat("set6 and dictionar6 exports, formals, and R6 objects verified.\n")
