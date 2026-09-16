#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: flip any pinned field and this test must fail.
stopifnot(identical(base$ifelse$return,
                    list(mode = 'yes_or_no', length = 'test', na = TRUE)))
stopifnot(identical(base$ifelse$return_mode,
                    list(kind = 'test_template', test = 'test', values = list('yes', 'no'))))

# The rule's own validity contract, mirroring `ry typeshed validate`:
# named parameters must exist, values must be non-empty, and the test
# formal must not also be a value.
params <- vapply(base$ifelse$params, function(param) param$name, character(1))
stopifnot(identical(params, c('test', 'yes', 'no')))
stopifnot(base$ifelse$return_mode$test %in% params)
stopifnot(length(base$ifelse$return_mode$values) > 0L)
stopifnot(all(unlist(base$ifelse$return_mode$values) %in% params))
stopifnot(!base$ifelse$return_mode$test %in% unlist(base$ifelse$return_mode$values))

# Live-R controls: ?ifelse builds its result from the test vector itself
# and overwrites only the selected positions, so the result mode is
# logical whenever the test is zero-length or entirely NA -- even when the
# branches agree on another mode -- and a mixed test coerces back to the
# branch mode. Branch values recycle to the test's length.
stopifnot(identical(ifelse(logical(0), 1L, 2L), logical(0)))
stopifnot(identical(ifelse(NA, 1L, 2L), NA))
stopifnot(identical(ifelse(c(NA, NA), 1L, 2L), c(NA, NA)))
stopifnot(identical(typeof(ifelse(c(TRUE, NA), 1L, 2L)), 'integer'))
stopifnot(identical(ifelse(c(TRUE, FALSE), 1L, 2L), c(1L, 2L)))
stopifnot(identical(ifelse(rep(TRUE, 3), 1:2, 2:3), c(1L, 2L, 1L)))

cat('ifelse test-template return-mode semantics passed\n')
