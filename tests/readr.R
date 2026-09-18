#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "readr"
version <- "2.2.0"
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

# R6 generators are exported objects; their $new members construct instances.
stopifnot(is.environment(readr::ChunkCallback), is.function(readr::ChunkCallback$new))
callback <- readr::SideEffectChunkCallback$new(function(x, pos) NULL)
stopifnot(inherits(callback, "SideEffectChunkCallback"), inherits(callback, "ChunkCallback"))

# Scalar and in-memory parsers return the expected typed values.
stopifnot(identical(readr::parse_number("$1,234.5"), 1234.5))
stopifnot(identical(readr::parse_logical("TRUE"), TRUE))
stopifnot(identical(readr::parse_datetime("2020-01-02"), as.POSIXct("2020-01-02", tz = "UTC")))
frame <- readr::read_csv(I("a,b\n1,2\n3,4"), col_types = "ii", lazy = FALSE)
stopifnot(identical(names(frame), c("a", "b")))
stopifnot(identical(frame$a, c(1L, 3L)), identical(frame$b, c(2L, 4L)))

cat("readr exports, formals, and parser behavior verified.\n")
