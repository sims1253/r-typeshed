#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))

# tibble::data_frame and vctrs::data_frame are dynamic-dots constructors:
# `!!!` splice and `!!name :=` are consumed before evaluation, which ry
# models through the injection metadata. Flip any pinned field and this
# test must fail.
tibble <- jsonlite::read_json(file.path(root, 'stubs/tibble/tibble.json'))$functions$data_frame
stopifnot(identical(tibble$params, list('...')))
stopifnot(identical(tibble$return, list(mode = 'opaque', length = 'unknown', na = TRUE)))
stopifnot(identical(tibble$injection, list('...' = 'splice')))

vctrs <- jsonlite::read_json(file.path(root, 'stubs/vctrs/vctrs.json'))$functions$data_frame
stopifnot(identical(vctrs$params[[1]], '...'))
stopifnot(identical(vctrs$injection, list('...' = 'splice')))

cat('tibble and vctrs data_frame dynamic-dots contracts passed\n')
