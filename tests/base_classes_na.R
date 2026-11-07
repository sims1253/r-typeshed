#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# #128: constructors that return S3 objects declare their class. Flip any
# pinned field and this test must fail.
returns <- list(
  table = list(mode = 'integer', length = 'unknown', na = FALSE,
               class = list('table')),
  proc.time = list(mode = 'double', length = '5', na = TRUE,
                   class = list('proc_time')),
  ordered = list(mode = 'integer', length = 'arg0', na = TRUE,
                 class = list('ordered', 'factor')),
  interaction = list(mode = 'integer', length = 'unknown', na = TRUE,
                     class = list('factor')),
  dist = list(mode = 'double', length = 'unknown', na = TRUE,
              class = list('dist')),
  # The class of these depends on the input, which a fixed class vector
  # cannot express, so they stay opaque instead of claiming one.
  factor = list(mode = 'opaque', length = 'arg0', na = TRUE),
  as.factor = list(mode = 'opaque', length = 'arg0', na = TRUE),
  ts = list(mode = 'opaque', length = 'unknown', na = TRUE)
)
for (entry in names(returns)) {
  stopifnot(identical(base[[entry]]$return, returns[[entry]]))
}

is_class <- function(x, class) identical(class(x), class)

tb <- table(c('a', 'b', NA))
stopifnot(is_class(tb, 'table'), identical(typeof(tb), 'integer'), !anyNA(tb))
stopifnot(is_class(table(c('a', 'b'), c('x', 'y')), 'table'))

pt <- proc.time()
stopifnot(is_class(pt, 'proc_time'), identical(typeof(pt), 'double'),
          identical(length(pt), 5L))
# Not witnessable on Linux: ?proc.time documents NA child times on Windows.
rd <- paste(capture.output(tools::Rd2txt(tools::Rd_db('base')[['proc.time.Rd']])),
            collapse = ' ')
stopifnot(grepl('always be given as .NA.', rd))

o <- ordered(c('a', 'b'))
stopifnot(is_class(o, c('ordered', 'factor')), identical(typeof(o), 'integer'),
          identical(length(o), 2L))
# Comparing an ordered factor with a level is valid (Ops.ordered).
stopifnot(identical(o < 'b', c(TRUE, FALSE)))

i <- interaction(c('a', 'b'), c('x', 'y'))
stopifnot(is_class(i, 'factor'), identical(typeof(i), 'integer'))
stopifnot(is_class(interaction(o, o), 'factor'))
stopifnot(is_class(interaction(c('a', 'b'), c('x', 'y'), lex.order = TRUE), 'factor'))

d <- dist(matrix(1:6, 3))
stopifnot(is_class(d, 'dist'), identical(typeof(d), 'double'), identical(length(d), 3L))

# factor() and as.factor() give "factor" for plain input but keep or add
# "ordered", and ts() adds "mts", "matrix", and "array" for a matrix and
# keeps the data's mode. start and end can also cut or recycle the data.
stopifnot(is_class(factor(c('a', 'b')), 'factor'))
stopifnot(is_class(factor(c('a', 'b'), ordered = TRUE), c('ordered', 'factor')))
stopifnot(is_class(factor(o), c('ordered', 'factor')))
stopifnot(is_class(as.factor(c('a', 'b')), 'factor'))
stopifnot(is_class(as.factor(o), c('ordered', 'factor')))
stopifnot(is_class(ts(1:10), 'ts'), identical(typeof(ts(1:10)), 'integer'))
stopifnot(identical(typeof(ts(c(1.5, 2))), 'double'))
stopifnot(is_class(ts(matrix(1:4, 2)), c('mts', 'ts', 'matrix', 'array')))
stopifnot(identical(length(ts(1:10, start = 1, end = 5)), 5L))

# #129: these entries declared na: false, but return NA or NaN for input
# containing NA. round() is rewritten and pinned with #124.
na_witnesses <- list(
  addmargins = quote(addmargins(matrix(c(1, NA, 3, 4), 2))),
  as.factor = quote(as.factor(c('a', NA))),
  as.table = quote(as.table(matrix(c(1, NA, 3, 4), 2))),
  basename = quote(basename(c('a', NA))),
  ceiling = quote(ceiling(c(1.5, NA))),
  dirname = quote(dirname(c('a', NA))),
  dist = quote(dist(matrix(c(NA, 1, NA, 2), 2))),
  factor = quote(factor(c('a', NA))),
  fft = quote(fft(c(1, NA))),
  floor = quote(floor(c(1.5, NA))),
  ftable = quote(ftable(matrix(c(1, NA, 3, 4), 2))),
  interaction = quote(interaction(c('a', NA), c('x', 'y'))),
  mvfft = quote(mvfft(matrix(c(1, NA, 3, 4), 2))),
  ordered = quote(ordered(c('a', NA))),
  prop.table = quote(prop.table(c(1, NA))),
  trunc = quote(trunc(c(1.5, NA))),
  ts = quote(ts(c(1, NA))),
  ts.intersect = quote(ts.intersect(ts(c(1, NA)), ts(1:2))),
  ts.union = quote(ts.union(ts(1:2), ts(1:2, start = 2)))
)
for (entry in names(na_witnesses)) {
  stopifnot(isTRUE(base[[entry]]$return$na))
  stopifnot(anyNA(unclass(eval(na_witnesses[[entry]]))))
}

cat('base constructor classes and NA claims passed\n')
