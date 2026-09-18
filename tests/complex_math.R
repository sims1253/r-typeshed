#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: flip any pinned field and this test must fail. Every entry
# below provably returns complex for complex input on R 4.6.1 (see the
# live-R witnesses), so the return is the double/complex union rather
# than a real-only double. Integer inputs still give double, hence
# double stays in the union.
fixed <- c('exp', 'log', 'log10', 'log2', 'sqrt', 'sin', 'cos', 'tan',
           'asin', 'acos', 'atan', 'sinh', 'cosh', 'tanh', 'signif')
for (entry in fixed) {
  stopifnot(identical(base[[entry]]$return,
                      list(mode = 'union', length = 'arg0',
                           members = list('double', 'complex'), na = TRUE)))
}

# Bare-string params stay inference-only: only the return contract changed.
bare_names <- function(entry) {
  vapply(base[[entry]]$params,
         function(param) if (is.character(param)) param else param$name,
         character(1))
}
stopifnot(identical(bare_names('log10'), 'x'))
stopifnot(identical(bare_names('log2'), 'x'))
stopifnot(identical(bare_names('sin'), 'x'))
stopifnot(identical(bare_names('cos'), 'x'))
stopifnot(identical(bare_names('tan'), 'x'))
stopifnot(identical(bare_names('asin'), 'x'))
stopifnot(identical(bare_names('acos'), 'x'))
stopifnot(identical(bare_names('atan'), 'x'))
stopifnot(identical(bare_names('sinh'), 'x'))
stopifnot(identical(bare_names('cosh'), 'x'))
stopifnot(identical(bare_names('tanh'), 'x'))
stopifnot(identical(bare_names('signif'), c('x', 'digits')))

z <- complex(real = 1, imaginary = 1)
zvec <- complex(real = c(1, 2, 3), imaginary = c(1, 2, 3))

# Complex input gives complex output with preserved length.
for (entry in fixed) {
  one <- get(entry, envir = baseenv())(z)
  stopifnot(identical(typeof(one), 'complex'), identical(length(one), 1L))
  many <- get(entry, envir = baseenv())(zvec)
  stopifnot(identical(typeof(many), 'complex'), identical(length(many), 3L))
}

# Integer and double inputs still give double.
for (entry in fixed) {
  stopifnot(identical(typeof(get(entry, envir = baseenv())(1L)), 'double'))
  stopifnot(identical(typeof(get(entry, envir = baseenv())(1)), 'double'))
}

# Zero-length complex stays complex and empty.
for (entry in fixed) {
  empty <- get(entry, envir = baseenv())(complex(0))
  stopifnot(identical(typeof(empty), 'complex'), identical(length(empty), 0L))
}

# signif propagates missingness, backing its na: true claim.
stopifnot(identical(typeof(signif(complex(real = NA_real_, imaginary = NA_real_))), 'complex'))
stopifnot(is.na(signif(NA_real_)))

# Deliberately unchanged: these entries keep their real-only double
# return because complex input errors on R 4.6.1.
excluded <- c('log1p', 'expm1', 'gamma', 'lgamma', 'digamma', 'trigamma',
              'floor', 'ceiling', 'trunc')
for (entry in excluded) {
  stopifnot(identical(base[[entry]]$return$mode, 'double'))
  msg <- tryCatch({ get(entry, envir = baseenv())(z); NULL },
                  error = function(e) conditionMessage(e))
  stopifnot(is.character(msg), grepl('complex', msg))
}

# The *pi variants have no stub entry and likewise reject complex input.
stopifnot(is.null(base$sinpi), is.null(base$cospi), is.null(base$tanpi))
for (entry in c('sinpi', 'cospi', 'tanpi')) {
  msg <- tryCatch({ get(entry, envir = baseenv())(z); NULL },
                  error = function(e) conditionMessage(e))
  stopifnot(is.character(msg), grepl('complex', msg))
}

cat('complex-capable math return modes passed\n')
