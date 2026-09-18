#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: flip any pinned field and this test must fail. as.vector is not
# an identity function, so it must not return arg0 (or mode: "arg0" -- even
# the storage mode can change); the return stays opaque until a consumer can
# prove the selected coercion.
stopifnot(identical(base$as.vector$return,
                    list(mode = 'opaque', length = 'unknown', na = TRUE)))
params <- vapply(base$as.vector$params, function(param) param, character(1))
stopifnot(identical(params, c('x', 'mode')))

# Live-R witnesses: mode selects the storage type, so mode = "list" turns an
# integer into a list whose absent member is NULL rather than an atomic-$ error.
stopifnot(identical(as.vector(1L, mode = 'list'), list(1L)))
stopifnot(is.null(as.vector(1L, mode = 'list')$missing))
stopifnot(identical(as.vector(1L, mode = 'character'), '1'))

# Factors default-coerce to character, and atomic results lose attributes.
stopifnot(identical(as.vector(factor('a')), 'a'))
stopifnot(is.null(attributes(as.vector(c(a = 1L)))))

# Mode binds by name in any order and positionally as the second argument.
stopifnot(identical(as.vector(x = 1L, mode = 'list'), list(1L)))
stopifnot(identical(as.vector(mode = 'list', x = 1L), list(1L)))
stopifnot(identical(as.vector(1L, 'list'), list(1L)))

# True-error control: $ on an atomic vector really does fail, so a checker
# that stays silent here (while flagging the list result above) is broken in
# the other direction.
err <- tryCatch({ 1L$missing; NULL }, error = function(e) conditionMessage(e))
stopifnot(is.character(err))

cat('as.vector coercion return contract passed\n')
