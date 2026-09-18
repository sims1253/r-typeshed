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

# The eight remaining distribution families carry the same correction
# (#72): recycling across value arguments, any-empty empties, NA
# propagation -- so the honest encoding is double/unknown/na: true.
family_d <- c('dbeta', 'dbinom', 'dchisq', 'dexp', 'df', 'dgamma', 'dlnorm', 'dt')
family_p <- c('pbeta', 'pbinom', 'pchisq', 'pexp', 'pf', 'pgamma', 'plnorm', 'pt')
family_q <- c('qbeta', 'qbinom', 'qchisq', 'qexp', 'qf', 'qgamma', 'qlnorm', 'qt')
for (name in c(family_d, family_p, family_q)) {
  stopifnot(identical(base[[name]]$return,
                      list(mode = 'double', length = 'unknown', na = TRUE)))
}
# Family-specific value formals are recorded completely (ncp where the
# family takes one; df renamed for the F density's `df` collision).
stopifnot(identical(unlist(base$dbeta$params), c('x', 'shape1', 'shape2', 'ncp', 'log')))
stopifnot(identical(unlist(base$dchisq$params), c('x', 'df', 'ncp', 'log')))
stopifnot(identical(unlist(base$dt$params), c('x', 'df', 'ncp', 'log')))
stopifnot(identical(unlist(base$dgamma$params), c('x', 'shape', 'rate', 'scale', 'log')))
stopifnot(identical(unlist(base$dlnorm$params), c('x', 'meanlog', 'sdlog', 'log')))
stopifnot(identical(unlist(base$dexp$params), c('x', 'rate', 'log')))
stopifnot(identical(unlist(base$dbinom$params), c('x', 'size', 'prob', 'log')))
stopifnot(identical(unlist(base$df$params), c('x', 'df1', 'df2', 'ncp', 'log')))
for (name in c(family_p, family_q)) {
  stopifnot(identical(tail(unlist(base[[name]]$params), 2L),
                      c('lower.tail', 'log.p')))
}

# Previously-missing inventory entries (#72): the Poisson quantile, the
# geometric family, and the binomial quantile join the corrected shape;
# dmultinom is a scalar density (one value per call, log-controlled),
# verified separately from the recycling families.
for (name in c('qpois', 'dgeom', 'pgeom', 'qgeom', 'qbinom')) {
  stopifnot(identical(base[[name]]$return,
                      list(mode = 'double', length = 'unknown', na = TRUE)))
}
stopifnot(identical(unlist(base$qpois$params), c('p', 'lambda', 'lower.tail', 'log.p')))
stopifnot(identical(unlist(base$dgeom$params), c('x', 'prob', 'log')))
stopifnot(identical(unlist(base$pgeom$params), c('q', 'prob', 'lower.tail', 'log.p')))
stopifnot(identical(unlist(base$qgeom$params), c('p', 'prob', 'lower.tail', 'log.p')))
stopifnot(identical(unlist(base$qbinom$params), c('p', 'size', 'prob', 'lower.tail', 'log.p')))
stopifnot(identical(base$dmultinom$return,
                    list(mode = 'double', length = '1', na = TRUE)))
stopifnot(identical(unlist(base$dmultinom$params), c('x', 'size', 'prob', 'log')))


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

# New-family witnesses: a recycling witness per family, plus NA and
# any-empty spot checks (shape parameters and ncp recycle like any other
# value argument).
stopifnot(identical(length(dbeta(0.5, c(1, 2), 1)), 2L))
stopifnot(identical(length(dbinom(c(1, 2), 10, 0.5)), 2L))
stopifnot(identical(length(dchisq(c(1, 2), 3, ncp = c(0, 1))), 2L))
stopifnot(identical(length(dexp(c(1, 2), rate = c(1, 2))), 2L))
stopifnot(identical(length(df(c(1, 2), 3, 4)), 2L))
stopifnot(identical(length(dgamma(1, shape = c(1, 2))), 2L))
stopifnot(identical(length(dlnorm(1, meanlog = c(0, 1))), 2L))
stopifnot(identical(length(dt(1, df = c(3, 4))), 2L))
stopifnot(identical(length(pbeta(0.5, c(1, 2), 1)), 2L))
stopifnot(identical(length(qbeta(c(.3, .7), 1, 2)), 2L))
stopifnot(identical(length(pf(c(1, 2), 3, 4)), 2L))
stopifnot(identical(length(qt(c(.3, .7), 5)), 2L))
stopifnot(is.na(dbeta(NA_real_, 1, 1)), is.na(pchisq(NA_real_, 1)), is.na(qf(NA_real_, 1, 1)))
stopifnot(identical(length(dbeta(c(.5, .6), 1, numeric(0))), 0L))
stopifnot(identical(length(dchisq(c(1, 2), numeric(0))), 0L))
stopifnot(identical(length(dbinom(c(1, 2), 10, numeric(0))), 0L))

# Missing-entry witnesses: the geometric family and the Poisson quantile
# recycle exactly like their siblings; dmultinom stays a scalar density.
stopifnot(identical(length(dgeom(c(0, 1), prob = .5)), 2L))
stopifnot(identical(length(pgeom(c(.2, .4), prob = .5)), 2L))
stopifnot(identical(length(qgeom(c(.2, .4), prob = .5)), 2L))
stopifnot(identical(length(qpois(c(.1, .2), lambda = 1)), 2L))
stopifnot(is.na(dgeom(NA_real_, prob = .5)))
stopifnot(identical(length(dmultinom(c(1, 1), prob = c(.5, .5))), 1L))
stopifnot(is.numeric(dmultinom(c(1, 1), prob = c(.5, .5), log = TRUE)))

# Expected-error control for a corrected family: the recycled length-2
# result is not a valid scalar condition.
err2 <- tryCatch({ if (dbeta(0.5, c(1, 2), 1)) 1L; NULL },
                 error = conditionMessage)
stopifnot(identical(err2, 'the condition has length > 1'))

cat('density/CDF/quantile recycling, NA, and empty-input semantics passed\n')
