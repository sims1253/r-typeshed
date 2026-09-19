#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "gridExtra"
version <- "2.3.1"
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

# Every export is a function in 2.3.1; the layout helpers return gtables
# and the grob constructors return grobs, all offline (nothing is drawn).
g <- gridExtra::tableGrob(data.frame(a = 1:2))
stopifnot(inherits(g, "gtable"), inherits(g, "grob"))
stopifnot(identical(dim(g), c(3L, 2L)))  # header + 2 rows, rowhead + 1 col
a <- gridExtra::arrangeGrob(grid::rectGrob())
stopifnot(inherits(a, "gtable"), identical(dim(a), c(1L, 1L)))
stopifnot(inherits(gridExtra::ngonGrob(0.5, 0.5, 5L), "grob"))
# polygon_regular closes the polygon: the first vertex repeats as the last
# row, so an n-gon has n + 1 vertices on the unit circle.
p <- gridExtra::polygon_regular(5L)
stopifnot(identical(dim(p), c(6L, 2L)), all(abs(p) <= 1))

cat("gridExtra exports, formals, and gtable/grob behavior verified.\n")
