script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
stub <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions[['model.extract']]
stopifnot(identical(unlist(stub$params), names(formals(stats::model.extract))))
stopifnot(identical(stub$eval, list(component = 'quoted_symbol')), is.null(stub$force))
stopifnot(identical(stub$return, list(mode = 'opaque', length = 'unknown', na = TRUE)))

mf <- stats::model.frame(y ~ x, data.frame(y = 1:3, x = 4:6))
expected <- stats::model.response(mf)
# An unbound symbol is the component name, not a caller lookup.
stopifnot(!exists('response', inherits = FALSE))
stopifnot(identical(stats::model.extract(mf, response), expected))
stopifnot(identical(stats::model.extract(component = response, frame = mf), expected))
stopifnot(identical(stats::model.extract(mf, comp = response), expected))
stopifnot(identical(stats::model.extract(mf, 'response'), expected))
# Neither implicit symbol-class registration nor caller lexical masks intercept
# the namespace's as.character conversion of a bare symbol.
for (class in c('name', 'symbol')) {
  method <- function(x, ...) stop('unexpected symbol dispatch')
  assign(paste0('as.character.', class), method, .GlobalEnv)
  registerS3method('as.character', class, method, envir = asNamespace('base'))
  stopifnot(identical(stats::model.extract(mf, response), expected))
}
local({
  as.character <- function(...) stop('unexpected caller mask')
  stopifnot(identical(stats::model.extract(mf, response), expected))
})
# Frame evaluation still forces the caller expression and keeps its effects.
forced <- FALSE
stopifnot(identical(stats::model.extract({ forced <- TRUE; mf }, response), expected), forced)
err <- tryCatch(stats::model.extract(stop('frame forced'), response), error = identity)
stopifnot(inherits(err, 'error'), identical(conditionMessage(err), 'frame forced'))

# Classed language is different from a bare symbol: coercion dispatch can run
# the expression. This prevents an unconditional quoted-expression contract.
as.character.ry_component <- function(x, ...) {
  get('component', envir = parent.frame(), inherits = FALSE)
}
expression <- structure(quote(stop('component forced')), class = 'ry_component')
call <- as.call(list(quote(stats::model.extract), quote(mf), expression))
err <- tryCatch(eval(call), error = identity)
stopifnot(inherits(err, 'error'), identical(conditionMessage(err), 'component forced'))
cat('model.extract symbol capture, frame evaluation, and coercion controls passed\n')
