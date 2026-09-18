#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: flip any pinned field and this test must fail.
for (name in c('dnorm', 'dpois', 'dunif', 'pnorm', 'ppois', 'punif', 'qnorm', 'qunif')) {
  stopifnot(identical(base[[name]]$return,
                      list(mode = 'double', length = 'unknown', na = TRUE)))
}
stopifnot(identical(unlist(base$dnorm$params),
                    c('x', 'mean', 'sd', 'log')))
stopifnot(identical(unlist(base$dpois$params),
                    c('x', 'lambda', 'log')))
stopifnot(identical(unlist(base$dunif$params),
                    c('x', 'min', 'max', 'log')))
for (name in c('pnorm', 'ppois', 'punif', 'qnorm', 'qunif')) {
  stopifnot(identical(tail(unlist(base[[name]]$params), 2L),
                      c('lower.tail', 'log.p')))
}

# Live-R witnesses: ?Normal, ?Poisson, and ?Uniform recycle across the
# numerical value arguments, so a scalar first argument does not pin a
# scalar result.
stopifnot(identical(length(dnorm(0, mean = c(0, 1))), 2L))
stopifnot(identical(length(dpois(0, lambda = c(1, 2))), 2L))
stopifnot(identical(length(dunif(0.5, min = 0, max = c(1, 2))), 2L))
stopifnot(identical(length(pnorm(0, mean = c(0, 1))), 2L))
stopifnot(identical(length(ppois(0, lambda = c(1, 2))), 2L))
stopifnot(identical(length(punif(0.5, max = c(1, 2))), 2L))
stopifnot(identical(length(qnorm(0.5, mean = c(0, 1))), 2L))
stopifnot(identical(length(qunif(0.5, min = c(0, 1))), 2L))

# Missing numerics propagate, in the first argument and in the parameters.
stopifnot(is.na(dnorm(NA_real_)))
stopifnot(is.na(dnorm(0, NA_real_)))
stopifnot(is.na(dnorm(0, 0, NA_real_)))
stopifnot(is.na(dpois(NA_real_, lambda = 1)))
stopifnot(is.na(dpois(1, lambda = NA_real_)))
stopifnot(is.na(dunif(NA_real_)))
stopifnot(is.na(dunif(0.5, min = NA_real_)))
stopifnot(is.na(pnorm(NA_real_)))
stopifnot(is.na(pnorm(0, mean = NA_real_)))
stopifnot(is.na(ppois(NA_real_, lambda = 1)))
stopifnot(is.na(punif(NA_real_)))
stopifnot(is.na(qnorm(NA_real_)))
stopifnot(is.na(qunif(NA_real_)))

# Scalar controls keep scalar calls scalar.
stopifnot(identical(length(dnorm(0)), 1L))
stopifnot(identical(length(dpois(0, 1)), 1L))
stopifnot(identical(length(dunif(0.5)), 1L))
stopifnot(identical(length(pnorm(0)), 1L))
stopifnot(identical(length(ppois(1, 2)), 1L))
stopifnot(identical(length(punif(0.5)), 1L))
stopifnot(identical(length(qnorm(0.5)), 1L))
stopifnot(identical(length(qunif(0.5)), 1L))

# Empty-input matrix: any empty numerical value argument empties the
# result -- unlike paste, which recycles "" for zero-length inputs.
stopifnot(identical(length(dnorm(numeric(0))), 0L))
stopifnot(identical(length(dnorm(numeric(0), c(0, 1))), 0L))
stopifnot(identical(length(dnorm(c(0, 1), mean = numeric(0))), 0L))
stopifnot(identical(length(dpois(numeric(0), 1)), 0L))
stopifnot(identical(length(dpois(c(0, 1), lambda = numeric(0))), 0L))
stopifnot(identical(length(dunif(numeric(0))), 0L))
stopifnot(identical(length(dunif(c(0.5, 0.6), min = numeric(0))), 0L))
stopifnot(identical(length(pnorm(c(0, 1), mean = numeric(0))), 0L))
stopifnot(identical(length(ppois(c(0, 1), lambda = numeric(0))), 0L))
stopifnot(identical(length(punif(c(0.5, 0.6), min = numeric(0))), 0L))
stopifnot(identical(length(qnorm(c(0.5, 0.6), mean = numeric(0))), 0L))
stopifnot(identical(length(qunif(c(0.5, 0.6), min = numeric(0))), 0L))

# Logical controls use only their first element and never contribute
# result length.
stopifnot(identical(length(dnorm(0, log = c(TRUE, FALSE))), 1L))
stopifnot(identical(length(dpois(0, 1, log = c(TRUE, FALSE))), 1L))
stopifnot(identical(length(dunif(0.5, log = c(TRUE, FALSE))), 1L))
stopifnot(identical(length(pnorm(0, lower.tail = c(TRUE, FALSE))), 1L))
stopifnot(identical(length(ppois(1, 2, log.p = c(TRUE, FALSE))), 1L))
stopifnot(identical(length(qnorm(0.5, lower.tail = c(TRUE, FALSE))), 1L))
stopifnot(identical(length(qunif(0.5, lower.tail = c(TRUE, FALSE))), 1L))

# Expected-error control: the recycled length-2 result is not a valid
# scalar condition.
err <- tryCatch({ if (dnorm(0, mean = c(0, 1))) 1L; NULL },
                error = conditionMessage)
stopifnot(identical(err, 'the condition has length > 1'))

cat('density/CDF/quantile recycling, NA, and empty-input semantics passed\n')
