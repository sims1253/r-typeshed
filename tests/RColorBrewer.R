#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "RColorBrewer"
version <- "1.1.3"
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

# Palette extraction returns fixed-length hex color vectors and the
# catalog data frame covers the three palette families.
blues <- RColorBrewer::brewer.pal(4, "Blues")
stopifnot(is.character(blues), length(blues) == 4L,
          all(grepl("^#[0-9A-F]{6}$", blues)))
info <- RColorBrewer::brewer.pal.info
stopifnot(is.data.frame(info),
          all(c("Blues", "BrBG", "Set1", "Spectral", "YlOrRd") %in% rownames(info)),
          setequal(unique(info$category), c("div", "qual", "seq")))
stopifnot(identical(RColorBrewer::brewer.pal(9, "Blues")[9L], "#08306B"))

cat("RColorBrewer exports, formals, and palette behavior verified.\n")
