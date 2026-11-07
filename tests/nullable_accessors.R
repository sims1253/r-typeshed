#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
stub <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))
base <- stub$functions

# Accessors that return NULL when the attribute is absent (#127). Each
# return admits NULL, and the length is unknown because the NULL member
# has length zero. Flip any pinned field and this test must fail.
nullable <- function(member, na) {
  list(mode = 'union', length = 'unknown', members = list(member, 'null'), na = na)
}
# dim(), nrow() and ncol() are opaque instead: they are NULL only when x
# has no dim, which the schema cannot express, and a NULL member makes ry
# report RY001 for the idiomatic if (nrow(df)) or if (dim(m)[1L]).
returns <- list(
  names = nullable('character', TRUE),
  rownames = nullable('character', TRUE),
  colnames = nullable('character', TRUE),
  dim = list(mode = 'opaque', length = 'unknown', na = FALSE),
  nrow = list(mode = 'opaque', length = 'unknown', na = FALSE),
  ncol = list(mode = 'opaque', length = 'unknown', na = FALSE),
  dimnames = nullable('list', TRUE)
)
for (entry in names(returns)) {
  stopifnot(identical(base[[entry]]$return, returns[[entry]]))
}
# dimnames gained a typed entry, so it left the untyped ambient inventory.
stopifnot(identical(base$dimnames$params, list('x')))
stopifnot(!'dimnames' %in% unlist(stub$globals$ambient_functions))
stopifnot(identical(names(formals(args(dimnames))), 'x'))

# A plain vector has none of these attributes.
for (f in list(names, rownames, colnames, dim, nrow, ncol, dimnames)) {
  stopifnot(is.null(f(1:3)))
}
stopifnot(is.null(names(list(1))), is.null(dimnames(matrix(1:4, 2))))

# With the attribute set, each keeps its non-NULL mode.
m <- matrix(1:4, 2, dimnames = list(c('a', 'b'), c('x', 'y')))
stopifnot(identical(typeof(names(c(a = 1))), 'character'))
stopifnot(identical(typeof(rownames(m)), 'character'))
stopifnot(identical(typeof(colnames(m)), 'character'))
stopifnot(identical(typeof(dim(m)), 'integer'))
stopifnot(identical(typeof(nrow(m)), 'integer'), identical(length(nrow(m)), 1L))
stopifnot(identical(typeof(ncol(m)), 'integer'), identical(length(ncol(m)), 1L))
stopifnot(identical(typeof(dimnames(m)), 'list'))
stopifnot(identical(typeof(nrow(data.frame(a = 1:2))), 'integer'))

# Names can be NA, which backs na: true for the character accessors.
x <- 1:2
names(x) <- c('a', NA)
stopifnot(anyNA(names(x)))
colnames(m) <- c('x', NA)
stopifnot(anyNA(colnames(m)), anyNA(dimnames(m)[[2]]))

# NROW and NCOL treat a vector as a one-column matrix and stay scalar
# integers, so their entries are unchanged.
stopifnot(identical(NROW(1:3), 3L), identical(NCOL(1:3), 1L))
stopifnot(identical(base$NROW$return, list(mode = 'integer', length = '1', na = FALSE)))
stopifnot(identical(base$NCOL$return, list(mode = 'integer', length = '1', na = FALSE)))

cat('nullable accessor returns passed\n')
