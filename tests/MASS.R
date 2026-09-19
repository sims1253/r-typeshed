#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "MASS"
version <- "7.3.66"
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)

# The upstream-drift CI job sets RT_TYPESHED_DRIFT so its probes reach the
# behavioral export/formal checks even when CRAN has moved past this
# recorded reference version; the required generators job never sets it.
# MASS is a recommended package bundled with R, but CI installs it through
# the normal pinned CRAN path (upstream-versions.json) so this gate is
# deterministic even when the runner's bundled recommended set moves.
if (Sys.getenv("RT_TYPESHED_DRIFT") == "") {
  stopifnot(identical(as.character(packageVersion(pkg)), version))
}
doc <- jsonlite::read_json(file.path(root, "stubs", pkg, paste0(pkg, ".json")))
exports <- getNamespaceExports(pkg)
functions <- exports[vapply(exports, function(name) {
  is.function(getExportedValue(pkg, name))
}, logical(1))]
values <- setdiff(exports, functions)
# MASS ships its datasets as lazy data: they are public through :: without
# appearing in the namespace export list (scripts/audit_typeshed.R resolves
# them the same way), so the value inventory unions the lazy-data database.
lazydata <- asNamespace(pkg)$.__NAMESPACE__.$lazydata
datasets <- setdiff(ls(lazydata, all.names = TRUE), functions)
values <- union(values, datasets)
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

# The Moore-Penrose inverse of an identity matrix is itself; fractions keeps
# the numeric value while carrying the rational representation; the histogram
# helper stays an exported closure without drawing anything.
stopifnot(isTRUE(all.equal(MASS::ginv(diag(3)), diag(3))))
frac <- MASS::fractions(1/2)
stopifnot(identical(as.numeric(frac), 1/2),
          identical(attr(frac, "fracs"), "1/2"),
          identical(class(frac), c("fractions", "numeric")))
stopifnot(is.function(MASS::truehist))

cat("MASS exports, formals, lazy datasets, and numerics verified.\n")
