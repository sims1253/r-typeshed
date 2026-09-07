#!/usr/bin/env Rscript
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
doc <- jsonlite::read_json(file.path(root, "stubs/base/base.json"))
spec <- doc$functions$expand.grid
stopifnot(identical(spec$return, list(mode = "opaque", length = "unknown", na = TRUE)))
stopifnot(identical(unlist(spec$params), names(formals(base::expand.grid))))

# Numeric dropped columns are vectors, not the enclosing list storage mode.
p23 <- expand.grid(0:2, 0:2)
stopifnot(is.data.frame(p23), is.integer(p23[, 1]),
          identical(2^p23[, 1] * 3^p23[, 2], c(1, 2, 4, 3, 6, 12, 9, 18, 36)))
named <- expand.grid(a = 1:2, c('b', 'a'), KEEP.OUT.ATTRS = FALSE,
                     stringsAsFactors = FALSE)
stopifnot(identical(names(named), c('a', 'Var2')), is.character(named$Var2),
          is.null(attr(named, 'out.attrs')))
stopifnot(is.factor(expand.grid(x = c('b', 'a'))$x))
stopifnot(identical(expand.grid(list(a = 1:2, b = 3:4)),
                    expand.grid(a = 1:2, b = 3:4)))
stopifnot(identical(dim(expand.grid()), c(0L, 0L)),
          identical(dim(expand.grid(list())), c(0L, 0L)),
          identical(dim(expand.grid(a = integer(), b = 1:2)), c(0L, 2L)))
# Controls follow dots and require exact names: abbreviations remain data columns.
partial <- expand.grid(x = 1:2, KEEP.OUT = FALSE, stringsAs = FALSE)
stopifnot(identical(names(partial), c('x', 'KEEP.OUT', 'stringsAs')),
          !is.null(attr(partial, 'out.attrs')))
stopifnot(inherits(try(expand.grid(x = 1, KEEP.OUT.ATTRS = NA), silent = TRUE), 'try-error'))
# Input subsetting can dispatch and affect the constructor's evaluation frame.
`[.ry_expand_contract` <- function(x, i, ...) {
  assign('structure', function(...) NA_real_, envir = parent.frame())
  unclass(x)[i]
}
custom <- expand.grid(structure(1:2, class = 'ry_expand_contract'), KEEP.OUT.ATTRS = FALSE)
stopifnot(identical(custom, NA_real_))
cat('expand.grid formals, dropped columns, controls, empty inputs, and dispatch passed\n')
