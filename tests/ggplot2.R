#!/usr/bin/env Rscript
# Pin the exported drawing helpers used by downstream ggtext packages.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
doc <- jsonlite::read_json(file.path(root, "stubs", "ggplot2", "ggplot2.json"))
exports <- getNamespaceExports("ggplot2")
lazydata <- ls(asNamespace("ggplot2")$.__NAMESPACE__.$lazydata)
stopifnot(all(c(names(doc$functions), names(doc$datasets)) %in% union(exports, lazydata)))
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

# Inventory every live export, without claiming result types for dispatched calls.
functions <- exports[vapply(exports, function(name) is.function(getExportedValue("ggplot2", name)), logical(1))]
stopifnot(setequal(names(doc$functions), functions))
stopifnot(setequal(names(doc$datasets), union(setdiff(exports, functions), lazydata)))
for (name in functions) {
  sig <- doc$functions[[name]]
  stopifnot(all(vapply(sig$params, is.character, logical(1))))
  stopifnot(identical(sig$return, list(mode = "opaque", length = "unknown", na = TRUE)))
  stopifnot(is.null(sig$force), is.null(sig$higher_order))
}
for (name in setdiff(names(doc$datasets), ".pt")) {
  stopifnot(identical(doc$datasets[[name]], list(mode = "opaque", length = "unknown", na = TRUE)))
}
# These rlang exports are the same callable, so their capture metadata applies.
rlang_doc <- jsonlite::read_json(file.path(root, "stubs", "rlang", "rlang.json"))
for (name in c("enexpr", "enquo", "enquos", "ensym", "ensyms", "expr", "quo")) {
  stopifnot(identical(getExportedValue("ggplot2", name), getExportedValue("rlang", name)))
  stopifnot(identical(doc$functions[[name]]$eval, rlang_doc$functions[[name]]$eval))
}
stopifnot(identical(rlang::quo_get_expr(ggplot2::aes(unbound_x, unbound_y)$x), quote(unbound_x)))
stopifnot(identical(rlang::quo_get_expr(ggplot2::vars(unbound_z)[[1L]]), quote(unbound_z)))
stopifnot(identical(doc$functions$aes$eval, list(x = "data_mask", y = "data_mask", "..." = "data_mask")))
stopifnot(identical(doc$functions$vars$eval, list("..." = "data_mask")))
for (name in c("qplot", "quickplot")) {
  stopifnot(identical(doc$functions[[name]]$eval, doc$functions$aes$eval))
  plot <- suppressWarnings(getExportedValue("ggplot2", name)(unbound_x, unbound_y,
    data = data.frame(unbound_x = 1, unbound_y = 2)))
  stopifnot(identical(rlang::quo_get_expr(plot$mapping$x), quote(unbound_x)))
}
stopifnot(identical(doc$functions$label_bquote$eval,
  list(rows = "quoted_expression", cols = "quoted_expression")))
stopifnot(is.function(ggplot2::label_bquote(rows = stop("must remain captured"))))
# Rd data-mask markers describe these helpers' use inside aes(), not direct calls.
for (name in c("after_stat", "after_scale", "from_theme", "stat")) {
  stopifnot(is.null(doc$functions[[name]]$eval))
  error <- tryCatch(getExportedValue("ggplot2", name)(stop("forced")), error = identity)
  stopifnot(inherits(error, "error"), identical(conditionMessage(error), "forced"))
}
stopifnot(is.null(doc$functions$stage$eval))
error <- tryCatch(ggplot2::stage(start = stop("forced")), error = identity)
stopifnot(inherits(error, "error"), identical(conditionMessage(error), "forced"))
cat("Complete ggplot2 export inventory and curated capture contracts verified.\n")
