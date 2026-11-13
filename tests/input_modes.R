#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# #125: these entries follow the mode of their data arguments through an
# `input_mode` rule. Each row lists the result mode for logical, integer,
# double, complex, and character input; NA marks an input R rejects, which
# the rule leaves out of `modes`. Flip any cell and this test must fail.
input_modes <- c('logical', 'integer', 'double', 'complex', 'character')
table <- list(
  sum = list(params = '...', modes = c('integer', 'integer', 'double', 'complex', NA)),
  cumsum = list(params = 'x', modes = c('integer', 'integer', 'double', 'complex', 'double')),
  diff = list(params = 'x', modes = c('integer', 'integer', 'double', 'complex', NA)),
  abs = list(params = 'x', modes = c('integer', 'integer', 'double', 'double', NA)),
  cummax = list(params = 'x', modes = c('integer', 'integer', 'double', NA, 'double')),
  cummin = list(params = 'x', modes = c('integer', 'integer', 'double', NA, 'double')),
  max = list(params = '...', modes = c('integer', 'integer', 'double', NA, 'character'),
             empty = 'double'),
  min = list(params = '...', modes = c('integer', 'integer', 'double', NA, 'character'),
             empty = 'double'),
  range = list(params = '...', modes = c('integer', 'integer', 'double', NA, 'character'),
               empty = 'double'),
  pmax = list(params = '...', modes = c(NA, 'integer', 'double', NA, 'character')),
  pmin = list(params = '...', modes = c(NA, 'integer', 'double', NA, 'character')),
  rowsum = list(params = 'x', modes = c(NA, 'integer', 'double', NA, NA))
)

# The stubs declare exactly this table, with an opaque fallback return.
for (name in names(table)) {
  entry <- base[[name]]
  row <- table[[name]]
  rule <- entry$return_mode
  declared <- unlist(rule$modes)[input_modes]
  names(declared) <- NULL
  stopifnot(identical(entry$return$mode, 'opaque'),
            identical(rule$kind, 'input_mode'),
            identical(unlist(rule$params), row$params),
            identical(declared, row$modes),
            identical(rule$empty, row$empty))
}
stopifnot(!grepl('double_or_int',
                 paste(readLines(file.path(root, 'stubs/base/base.json')), collapse = '')))

# Every cell against live R: typeof() of the call, or NA when R errors.
mode_of <- function(f, x) {
  tryCatch(suppressWarnings(typeof(f(x))), error = function(e) NA_character_)
}
inputs <- list(c(TRUE, FALSE), 1:2, c(1.5, 2), complex(real = 1:2, imaginary = 1),
               c('1', '2'))
for (name in names(table)) {
  f <- match.fun(name)
  if (name == 'rowsum') f <- function(x) rowsum(x, c(1, 1))
  observed <- vapply(inputs, mode_of, '', f = f)
  if (name %in% c('pmax', 'pmin')) observed[[1]] <- NA_character_
  stopifnot(identical(observed, table[[name]]$modes))
}

# pmax and pmin leave all-logical data out of `modes`: one argument keeps
# logical, but two or more arguments give integer.
for (f in list(pmax, pmin)) {
  stopifnot(identical(typeof(f(c(TRUE, FALSE))), 'logical'),
            identical(typeof(f(TRUE, FALSE)), 'integer'),
            identical(typeof(f(TRUE, NA)), 'integer'))
}

# The data join on the coercion ladder; na.rm is not data.
stopifnot(identical(typeof(max(TRUE, 'a')), 'character'),
          identical(typeof(sum(TRUE, 1i)), 'complex'),
          identical(typeof(pmax(TRUE, 2L)), 'integer'),
          identical(typeof(max(1L, 2.5)), 'double'),
          identical(typeof(sum(1:3, na.rm = TRUE)), 'integer'),
          identical(typeof(sum(1+1i)), 'complex'))

# `empty`: max, min, and range return -Inf/Inf, a double, when the data
# supply no element, including after na.rm = TRUE drops every NA.
# Character data stay character, and the other members keep integer.
stopifnot(identical(typeof(suppressWarnings(max(integer(0)))), 'double'),
          identical(typeof(suppressWarnings(min(logical(0)))), 'double'),
          identical(typeof(suppressWarnings(range(integer(0)))), 'double'),
          identical(typeof(suppressWarnings(max(NA_integer_, na.rm = TRUE))), 'double'),
          identical(typeof(suppressWarnings(max(character(0)))), 'character'),
          identical(typeof(max(integer(0), 1L)), 'integer'),
          identical(typeof(max(c(TRUE, NA), na.rm = TRUE)), 'integer'),
          identical(typeof(sum(integer(0))), 'integer'),
          identical(typeof(sum(NA_integer_, na.rm = TRUE)), 'integer'),
          identical(typeof(cumsum(integer(0))), 'integer'),
          identical(typeof(pmax(integer(0))), 'integer'))

cat('input-following result modes passed\n')
