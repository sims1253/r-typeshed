#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "lifecycle"
version <- "1.0.5"
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)

# The upstream-drift CI job sets RT_TYPESHED_DRIFT so its probes reach the
# behavioral export/formal checks even when CRAN has moved past this
# recorded reference version; the required generators job never sets it.
if (Sys.getenv("RT_TYPESHED_DRIFT") == "") {
  stopifnot(identical(as.character(packageVersion(pkg)), version))
}
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

# The sentinel is the missing argument, is_present() distinguishes defaults
# from supplied arguments, and the warning log starts as an empty classed
# list. The signaling deprecate_soft(), deprecate_warn(), and
# deprecate_stop() are inventoried but never called.
stopifnot(identical(lifecycle::deprecated(), quote(expr = )))
present <- function(x = lifecycle::deprecated()) lifecycle::is_present(x)
stopifnot(identical(present(), FALSE), identical(present(1), TRUE))
warnings_log <- lifecycle::last_lifecycle_warnings()
stopifnot(is.list(warnings_log), length(warnings_log) == 0L,
          inherits(warnings_log, "lifecycle_warnings"))

cat("lifecycle exports, formals, and sentinel behavior verified.\n")
