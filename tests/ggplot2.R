#!/usr/bin/env Rscript
# Pin the exported drawing helpers used by downstream ggtext packages.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
doc <- jsonlite::read_json(file.path(root, "stubs", "ggplot2", "ggplot2.json"))
exports <- getNamespaceExports("ggplot2")
stopifnot(all(c(names(doc$functions), names(doc$datasets)) %in% exports))
for (name in names(doc$functions)) {
  fn <- getExportedValue("ggplot2", name)
  stopifnot(is.function(fn))
  stopifnot(identical(unlist(doc$functions[[name]]$params, use.names = FALSE), names(formals(fn))))
  stopifnot(identical(doc$functions[[name]]$return$mode, "opaque"))
}
# R skips a same-named NULL parameter when finding a callable in the namespace.
local({
  margin <- ggplot2::margin
  make_margin <- function(margin = NULL) {
    if (is.null(margin)) margin <- margin(1, 2, 3, 4)
    margin
  }
  value <- make_margin()
  stopifnot(inherits(value, "unit"), identical(as.numeric(value), c(1, 2, 3, 4)))
})
stopifnot(is.environment(ggplot2::Geom), !is.function(ggplot2::Geom))
stopifnot(identical(doc$datasets$Geom$mode, "opaque"))
stopifnot(identical(typeof(ggplot2::.pt), doc$datasets$.pt$mode))
stopifnot(identical(length(ggplot2::.pt), as.integer(doc$datasets$.pt$length)))
stopifnot(!anyNA(ggplot2::.pt), !doc$datasets$.pt$na)
# Measuring a key opens a graphics device; use an in-memory device explicitly.
local({
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off())
  key <- ggplot2::draw_key_text(list(label = "a", colour = "black", size = 3), list(), 5)
  stopifnot(grid::is.grob(key))
})
cat("ggplot2 drawing exports and callable fallback verified.\n")
