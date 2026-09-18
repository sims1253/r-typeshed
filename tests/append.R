#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: flip any pinned field and this test must fail.
stopifnot(identical(base$append$params,
                    list('x', 'values', 'after')))
stopifnot(identical(base$append$return,
                    list(mode = 'opaque', length = 'unknown', na = TRUE)))

# The restored inference-only formals match R's real signature; `after`
# defaults to `length(x)`, so an omitted control appends at the end.
stopifnot(identical(names(formals(append)), c('x', 'values', 'after')))

# Live-R witnesses: ?append inserts `values` after position `after` in `x`.
# `after` is an insertion-position control, not concatenated data.
stopifnot(identical(append(1L, 2L), c(1L, 2L)))
stopifnot(identical(append(1L, 2L, after = 0), c(2L, 1L)))
stopifnot(identical(append(x = 1L, values = 2L, after = 0), c(2L, 1L)))
stopifnot(identical(append(values = 2L, after = 0, x = 1L), c(2L, 1L)))
stopifnot(identical(append(1L, values = 2L, 0), c(2L, 1L)))
stopifnot(identical(append(1L, 2L, 0), c(2L, 1L)))
stopifnot(identical(append(1L, 2L, after = 1), c(1L, 2L)))
stopifnot(identical(append(c(1L, 2L, 3L), 9L, after = 2), c(1L, 2L, 9L, 3L)))

# The old `concat_of_args` contract folded `after` into the result, claiming
# double of length 3 here; R gives an integer of length 2.
stopifnot(identical(typeof(append(1L, 2L, after = 0)), 'integer'))
stopifnot(identical(length(append(1L, 2L, after = 0)), 2L))

# Empty inputs stay empty on their own side; they do not error.
stopifnot(identical(append(logical(0), TRUE, after = 0L), TRUE))
stopifnot(identical(append(integer(0), integer(0)), integer(0)))
stopifnot(identical(append(1L, integer(0)), 1L))

# Atomic coercion follows the ordinary `c()` ladder.
stopifnot(identical(append(1L, 2.5), c(1, 2.5)))
stopifnot(identical(append(c('a', 'b'), 1L, after = 1), c('a', '1', 'b')))

# List inputs concatenate as lists.
stopifnot(identical(append(list(1), list(2)), list(1, 2)))
stopifnot(identical(append(list('a'), list(1L, TRUE)), list('a', 1L, TRUE)))

# Downstream length shape: a length-1 result is a legal `if` condition, so
# `after` must not manufacture a second element for the checker.
stopifnot(identical(if (append(logical(0), TRUE, after = 0L)) 1L, 1L))

# True-error control: without `after`, the concatenation really is length 2,
# so this `if` must keep failing once a precise consumer rule lands.
err <- tryCatch({ if (append(FALSE, TRUE)) 1L; NULL },
                error = function(e) conditionMessage(e))
stopifnot(!is.null(err), grepl('length > 1', err))

cat('append insertion-position and coercion semantics passed\n')
