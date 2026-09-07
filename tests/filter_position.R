base <- jsonlite::fromJSON('stubs/base/base.json', simplifyVector = FALSE)
for (name in c('Filter', 'Position')) {
  sig <- base$functions[[name]]
  stopifnot(identical(vapply(sig$params, `[[`, character(1), 'name'), names(formals(get(name, baseenv())))))
  stopifnot(identical(sig$return$mode, 'opaque'), identical(sig$return$length, 'unknown'), isTRUE(sig$return$na))
  stopifnot(identical(sig$higher_order$result, list(kind = 'vector_of', mode = 'opaque')))
  stopifnot(identical(sig$higher_order$callback_param, 'f'), identical(unlist(sig$higher_order$callback_args), 'element_of_arg1'))
}
stopifnot(identical(Filter(function(x) FALSE, 1L), integer()))
stopifnot(identical(Filter(function(x) NA, 1:2), integer()))
stopifnot(identical(Filter(function(x) NULL, list(1L)), list()))
stopifnot(identical(Filter(function(x) stop('not called'), integer()), integer()))
stopifnot(identical(Filter(function(x) c(TRUE, FALSE, TRUE), 1:2), c(1L, NA_integer_, NA_integer_, NA_integer_)))
x <- structure(1:2, class = 'ry_filter')
`[.ry_filter` <- function(x, i, ...) list(value = NA_character_, extra = 1:3)
stopifnot(identical(Filter(function(x) TRUE, x), list(value = NA_character_, extra = 1:3)))

stopifnot(identical(Position(function(x) FALSE, 1:3), NA_integer_))
for (nomatch in list(NULL, c('a', 'b'), list(value = NA_real_))) {
  stopifnot(identical(Position(function(x) FALSE, 1:3, nomatch = nomatch), nomatch))
  stopifnot(identical(Position(function(x) FALSE, 1:3, FALSE, nomatch), nomatch))
  stopifnot(identical(Position(function(x) FALSE, 1:3, nom = nomatch), nomatch))
  stopifnot(identical(Position(function(x) stop('not called'), integer(), nomatch = nomatch), nomatch))
}
stopifnot(identical(Position(function(x) TRUE, 1:3), 1L))
stopifnot(identical(Position(function(x) TRUE, 1:3, right = TRUE), 3L))
stopifnot(identical(Position(function(x) x + 1L > 0L, list('a', 1L), right = TRUE), 2L))
# Result uncertainty must not remove ordinary callback errors.
expect_error <- function(expr) stopifnot(inherits(tryCatch(force(expr), error = identity), 'error'))
expect_error(Filter(function(x) x + 'a', 1:2))
for (right in c(FALSE, TRUE)) expect_error(Position(function(x) x + 'a', 1:2, right = right))
# Classed extraction can change callback input types; these are runtime controls,
# not a claim that the consumer currently models custom coercion/extraction.
x <- structure(c('a', 'b'), class = 'ry_input')
as.list.ry_input <- function(x, ...) list(1L, 2L)
`[.ry_input` <- function(x, i, ...) list(value = NA_real_)
`[[.ry_input` <- function(x, i, ...) 1L
stopifnot(identical(Filter(function(x) x + 1L > 0L, x), list(value = NA_real_)))
stopifnot(identical(Position(function(x) x + 1L > 0L, x, right = TRUE), 2L))
cat('Filter and Position lengths, missingness, no-match values, callback errors, and dispatch controls passed\n')
