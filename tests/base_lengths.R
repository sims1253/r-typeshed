#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: flip any pinned field and this test must fail.
stopifnot(identical(base$file.path$return,
                    list(mode = 'character', length = 'longest_arg_or_zero', na = FALSE)))
stopifnot(identical(base$sprintf$return,
                    list(mode = 'character', length = 'longest_arg_or_zero', na = TRUE)))
stopifnot(identical(base$seq_len$return,
                    list(mode = 'integer', length = 'unknown', na = FALSE)))
stopifnot(identical(base$seq_len$return_length,
                    list(kind = 'param_value', param = 'length.out', default_length = 0L)))

# Live-R controls: ?file.path recycles to the longest argument, but any
# zero-length argument yields an empty character vector (unlike paste,
# which recycles "" for zero-length arguments).
stopifnot(identical(file.path(c('a', 'b'), 'x'), c('a/x', 'b/x')))
stopifnot(identical(file.path('a', 'b'), 'a/b'))
stopifnot(identical(file.path('a', character(0)), character(0)))
stopifnot(identical(length(paste0('a', character(0))), 1L))
# sprintf recycles fmt and its values the same way, and a zero-length
# fmt or value likewise yields character(0).
stopifnot(identical(sprintf('%s-%s', c('a', 'b'), 'x'), c('a-x', 'b-x')))
stopifnot(identical(sprintf('%s-%s', c('a', 'b'), character(0)), character(0)))
stopifnot(identical(sprintf(character(0), 1), character(0)))

# seq_len's result length is the *value* of length.out, not its vector
# length: 0 empties, scalars pass through, dynamic counts stay runtime.
stopifnot(identical(seq_len(0L), integer(0)))
stopifnot(identical(seq_len(3L), 1:3))
stopifnot(identical(length(seq_len(nrow(data.frame(a = 1:2)))), 2L))

# #134 & #137: round(), signif(), log(), startsWith(), and endsWith() recycle
# their second argument; file.exists() is variadic (`...`).
for (pair in list(
  c('round', 'digits'),
  c('signif', 'digits'),
  c('log', 'base'),
  c('startsWith', 'prefix'),
  c('endsWith', 'suffix')
)) {
  fn <- pair[[1L]]
  arg2 <- pair[[2L]]
  stopifnot(identical(base[[fn]]$return$length, 'unknown'))
  stopifnot(identical(base[[fn]]$return_length, list(
    kind = 'recycled_values',
    value_params = list('x', arg2),
    any_value_zero = 'zero'
  )))
}
stopifnot(identical(base$file.exists$return$length, 'unknown'))

stopifnot(
  identical(length(round(1.234, 1:3)), 3L),
  identical(length(signif(1.234, 1:3)), 3L),
  identical(length(log(2, 1:3)), 3L),
  identical(length(round(1:5, 1:2)), 5L),
  identical(length(startsWith('abc', c('a', 'b', 'c'))), 3L),
  identical(length(endsWith('abc', c('a', 'b', 'c'))), 3L),
  identical(length(startsWith('abc', character(0))), 0L),
  identical(length(endsWith('abc', character(0))), 0L),
  identical(length(file.exists('a', c('b', 'c'))), 3L)
)

cat('file.path, sprintf, recycled-argument, and seq_len length semantics passed\n')
