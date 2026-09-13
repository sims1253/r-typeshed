#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "scales"
version <- "1.4.0"
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

# R6 generators are exported objects; their $new members construct instances.
stopifnot(is.environment(scales::DiscreteRange), is.function(scales::DiscreteRange$new))
stopifnot(inherits(scales::Range$new(), "Range"))
stopifnot(inherits(scales::DiscreteRange$new(), c("DiscreteRange", "Range")))

# Rescaling maps onto [0, 1], palettes emit hex colors, formatters strings.
stopifnot(identical(scales::rescale(c(1, 2, 3)), c(0, 0.5, 1)))
hex <- scales::hue_pal()(2L)
stopifnot(is.character(hex), identical(length(hex), 2L), all(grepl("^#[0-9A-F]{6}$", hex)))
stopifnot(is.character(scales::number_format()(1234.56)))

cat("scales exports, formals, and R6 range generators verified.\n")
