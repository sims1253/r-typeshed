#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
sig <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions$Find
stopifnot(identical(vapply(sig$params, `[[`, character(1), 'name'), names(formals(base::Find))))
stopifnot(identical(sig$return, list(mode = 'opaque', length = 'unknown', na = TRUE)))
stopifnot(identical(sig$higher_order$result, list(kind = 'vector_of', mode = 'opaque')))
stopifnot(identical(sig$higher_order$callback_param, 'f'),
          identical(unlist(sig$higher_order$callback_args), 'element_of_arg1'))

expect_error <- function(expr, message) {
  error <- tryCatch(force(expr), error = identity)
  stopifnot(inherits(error, 'error'), grepl(message, conditionMessage(error), fixed = TRUE))
}
for (right in c(FALSE, TRUE)) {
  stopifnot(identical(Find(function(x) FALSE, 1:3, right = right), NULL))
  for (nomatch in list(NULL, integer(), c('a', 'b'), list(value = NA_real_))) {
    stopifnot(identical(Find(function(x) FALSE, 1:3, right = right, nomatch = nomatch), nomatch))
    stopifnot(identical(Find(function(x) FALSE, 1:3, right, nomatch), nomatch))
    stopifnot(identical(Find(function(x) FALSE, 1:3, right = right, nom = nomatch), nomatch))
    stopifnot(identical(Find(function(x) stop('callback called'), integer(), right = right,
                           nomatch = nomatch), nomatch))
  }
  stopifnot(identical(Find(function(x) TRUE, list(integer()), right = right), integer()))
  stopifnot(identical(Find(function(x) TRUE, list(c(1L, 2L)), right = right), c(1L, 2L)))
  stopifnot(identical(Find(function(x) TRUE, list(list(value = NA_real_)), right = right),
                      list(value = NA_real_)))
  stopifnot(identical(Find(function(x) TRUE, list(NA_real_), right = right), NA_real_))
  stopifnot(identical(Find(function(x) TRUE, 1L, right = right,
                          nomatch = stop('nomatch forced')), 1L))
  expect_error(Find(function(x) stop('predicate error'), 1:2, right = right), 'predicate error')
}
stopifnot(identical(Find(function(x) TRUE, 1:3), 1L),
          identical(Find(function(x) TRUE, 1:3, right = TRUE), 3L))
# Both directions stop before reaching the invalid later predicate operand.
stopifnot(identical(Find(function(x) x + 1L > 0L, list(1L, 'a')), 1L),
          identical(Find(function(x) x + 1L > 0L, list('a', 1L), right = TRUE), 1L))
# An empty search still inspects direction, but does not invoke the callback body.
expect_error(Find(function(x) stop('callback called'), integer(),
                  right = stop('direction forced')), 'direction forced')
# But Find still resolves the callback before testing input length.
expect_error(Find(stop('callback expression forced'), integer()), 'callback expression forced')
# Extraction may dispatch; the matching value need not have the storage mode of x.
`[[.ry_find` <- function(x, i, ...) list(value = NA_character_)
x <- structure(1:2, class = 'ry_find')
stopifnot(identical(Find(function(x) TRUE, x), list(value = NA_character_)))
cat('Find result shapes, matching controls, early exits, laziness, and callback errors passed\n')
