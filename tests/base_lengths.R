#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: flip any pinned field and this test must fail.
stopifnot(identical(base$file.path$return,
                    list(mode = 'character', length = 'longest_arg_or_zero', na = FALSE)))
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

# seq_len's result length is the *value* of length.out, not its vector
# length: 0 empties, scalars pass through, dynamic counts stay runtime.
stopifnot(identical(seq_len(0L), integer(0)))
stopifnot(identical(seq_len(3L), 1:3))
stopifnot(identical(length(seq_len(nrow(data.frame(a = 1:2)))), 2L))

cat('file.path recycling and seq_len value-length semantics passed\n')
