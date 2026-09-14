#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))

# Dynamic-dots constructors: !!! splice and !!name := (and, for the quos
# defusers, bare-RHS !!) are consumed before evaluation, which ry models
# through the injection metadata. Flip any pinned field and this test
# must fail; vctrs::data_frame's formals are additionally live-pinned by
# the audit_function_semantics.R loop.
tibble <- jsonlite::read_json(file.path(root, 'stubs/tibble/tibble.json'))$functions
expected_params <- list(
  data_frame = list('...'),
  tibble = list('...', '.rows', '.name_repair'),
  tibble_row = list('...', '.name_repair'),
  lst = list('...')
)
for (name in names(expected_params)) {
  sig <- tibble[[name]]
  stopifnot(identical(sig$params, expected_params[[name]]))
  stopifnot(identical(sig$injection, list('...' = 'full')))
}

vctrs <- jsonlite::read_json(file.path(root, 'stubs/vctrs/vctrs.json'))$functions$data_frame
stopifnot(identical(
  vctrs$params,
  list('...',
       list(name = '.size', default = TRUE),
       list(name = '.name_repair', default = TRUE),
       list(name = '.error_call', default = TRUE))
))
stopifnot(identical(vctrs$injection, list('...' = 'splice')))

cat('tibble and vctrs data_frame dynamic-dots contracts passed\n')
