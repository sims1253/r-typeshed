#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "zoo"
version <- "1.9.0"
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

# Constructor, index/coredata accessors, and the na.locf/rollmean/field
# families: zoo builds ordered observations whose coredata drops the index,
# na.locf carries values forward (na.rm = FALSE keeps leading NAs),
# rollmean windows are verified doubles, and yearmon formatting is asserted
# through an explicit %Y-%m format, not the locale-dependent %b default.
z <- zoo::zoo(c(10, 20), order.by = as.Date(c("2020-01-01", "2020-01-02")))
stopifnot(zoo::is.zoo(z), identical(length(z), 2L))
stopifnot(identical(zoo::coredata(z), c(10, 20)))
stopifnot(identical(zoo::index(z), as.Date(c("2020-01-01", "2020-01-02"))))
stopifnot(identical(zoo::na.locf(c(NA, 1, NA), na.rm = FALSE), c(NA, 1, 1)))
stopifnot(identical(zoo::rollmean(c(1, 2, 3, 4), k = 2L), c(1.5, 2.5, 3.5)))
stopifnot(identical(as.character(zoo::as.yearmon(c("2020-01-01", "2020-02-01")),
                                 format = "%Y-%m"),
                    c("2020-01", "2020-02")))

cat("zoo exports, formals, and series behavior verified.\n")
