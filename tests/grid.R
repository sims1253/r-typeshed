#!/usr/bin/env Rscript
# Verify the exported inventory without executing arbitrary drawing functions.
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
doc <- jsonlite::read_json(file.path(root, "stubs/grid/grid.json"))
exports <- getNamespaceExports("grid")
functions <- exports[vapply(exports, function(name) is.function(getExportedValue("grid", name)), logical(1))]
stopifnot(setequal(names(doc$functions), functions))
stopifnot(setequal(names(doc$datasets), setdiff(exports, functions)))
for (name in functions) {
  sig <- doc$functions[[name]]
  declared <- vapply(sig$params, function(param) if (is.character(param)) param else param$name, character(1))
  actual <- names(formals(getExportedValue("grid", name)))
  if (is.null(actual)) actual <- character()
  stopifnot(identical(unname(declared), actual))
  stopifnot(identical(sig$return, list(mode = "opaque", length = "unknown", na = TRUE)))
  stopifnot(is.null(sig$force), is.null(sig$higher_order))
}
for (name in c("delayGrob", "grid.delay", "grid.record", "recordGrob")) {
  stopifnot(identical(doc$functions[[name]]$eval$expr, "quoted_expression"))
}
# Constructors capture the expression, including an omitted expression, without
# forcing it. Drawing the result is a separate operation.
for (constructor in list(grid::delayGrob, grid::recordGrob)) {
  result <- constructor(stop("must remain captured"), list = list())
  stopifnot(inherits(result, "grob"), identical(result$expr, quote(stop("must remain captured"))))
  stopifnot(inherits(constructor(list = list()), "grob"))
}
# A dispatched drawing method can ignore recording and choose any return type.
grid.draw.inventory_probe <- function(x, recording) "custom"
stopifnot(identical(grid::grid.draw(structure(list(), class = "inventory_probe")), "custom"))
cat("grid export/formal inventory and capture controls passed\n")
