#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# #125 / #137: these entries follow the mode of their data arguments through an
# `input_mode` rule. Each row lists the result mode(s) for logical, integer,
# double, complex, and character input; NULL marks an input R rejects, which
# the rule leaves out of `modes`. Flip any cell and this test must fail.
input_modes <- c('logical', 'integer', 'double', 'complex', 'character')
table <- list(
  sum = list(params = '...',
             modes = list('integer', c('integer', 'double'), 'double', 'complex', NULL),
             drop_controls = 'na.rm'),
  cumsum = list(params = 'x', modes = list('integer', 'integer', 'double', 'complex', 'double')),
  diff = list(params = 'x', modes = list('integer', 'integer', 'double', 'complex', NULL)),
  abs = list(params = 'x', modes = list('integer', 'integer', 'double', 'double', NULL)),
  cummax = list(params = 'x', modes = list('integer', 'integer', 'double', NULL, 'double')),
  cummin = list(params = 'x', modes = list('integer', 'integer', 'double', NULL, 'double')),
  max = list(params = '...', modes = list('integer', 'integer', 'double', NULL, 'character'),
             empty = 'double'),
  min = list(params = '...', modes = list('integer', 'integer', 'double', NULL, 'character'),
             empty = 'double'),
  range = list(params = '...', modes = list('integer', 'integer', 'double', NULL, 'character'),
               empty = 'double',
               drop_controls = c('na.rm', 'finite')),
  pmax = list(params = '...', modes = list(NULL, 'integer', 'double', NULL, 'character')),
  pmin = list(params = '...', modes = list(NULL, 'integer', 'double', NULL, 'character')),
  rowsum = list(params = 'x', modes = list(NULL, 'integer', 'double', NULL, NULL))
)

# The stubs declare exactly this table, with an opaque fallback return.
for (name in names(table)) {
  entry <- base[[name]]
  row <- table[[name]]
  rule <- entry$return_mode
  declared <- lapply(input_modes, function(m) {
    v <- rule$modes[[m]]
    if (is.null(v)) NULL else unlist(v, use.names = FALSE)
  })
  declared_controls <- if (is.null(rule$drop_controls)) NULL else unlist(rule$drop_controls, use.names = FALSE)
  stopifnot(identical(entry$return$mode, 'opaque'),
            identical(rule$kind, 'input_mode'),
            identical(unlist(rule$params), row$params),
            identical(declared, row$modes),
            identical(rule$empty, row$empty),
            identical(declared_controls, row$drop_controls))
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
  for (i in seq_along(input_modes)) {
    allowed <- table[[name]]$modes[[i]]
    if (is.null(allowed)) {
      stopifnot(is.na(observed[[i]]))
    } else {
      stopifnot(observed[[i]] %in% allowed)
    }
  }
}

# #137: sum() integer overflow promotes to double in GNU R, and range(..., finite = ...)
# treats `finite` as a drop control rather than logical data.
stopifnot(identical(typeof(sum(2147483647L, 1L)), 'double'),
          identical(typeof(sum(c(2147483647L, 1L))), 'double'),
          identical(typeof(suppressWarnings(range(integer(0), finite = FALSE))), 'double'),
          identical(typeof(suppressWarnings(range(NA_integer_, finite = TRUE))), 'double'),
          identical(typeof(range(1L, finite = FALSE)), 'integer'))

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
