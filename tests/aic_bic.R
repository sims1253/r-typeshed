#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
doc <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))
spec_aic <- doc$functions$AIC
spec_bic <- doc$functions$BIC

# Stub pins: flip any pinned field and this test must fail.
opaque <- list(mode = 'opaque', length = 'unknown', na = TRUE)
stopifnot(identical(spec_aic$return, opaque))
stopifnot(identical(spec_bic$return, opaque))
declared_aic <- vapply(spec_aic$params, function(param) if (is.character(param)) param else param$name, character(1))
declared_bic <- vapply(spec_bic$params, function(param) if (is.character(param)) param else param$name, character(1))
stopifnot(identical(unname(declared_aic), names(formals(stats::AIC))))
stopifnot(identical(unname(declared_bic), names(formals(stats::BIC))))

# Single-model calls return one numeric value.
m1 <- stats::lm(mpg ~ wt, data = datasets::mtcars)
m2 <- stats::lm(mpg ~ wt + hp, data = datasets::mtcars)
single_aic <- stats::AIC(m1)
single_bic <- stats::BIC(m1)
stopifnot(is.numeric(single_aic), length(single_aic) == 1L)
stopifnot(is.numeric(single_bic), length(single_bic) == 1L)

# Multi-model calls return data frames, so a scalar-double contract would
# be wrong for this common supported API shape.
a <- stats::AIC(m1, m2)
b <- stats::BIC(m1, m2)
stopifnot(is.data.frame(a), identical(names(a), c('df', 'AIC')))
stopifnot(is.data.frame(b), identical(names(b), c('df', 'BIC')))
# The $ accesses the old contract flagged as atomic-vector errors are
# legitimate data-frame column accesses here.
stopifnot(is.numeric(a$AIC), length(a$AIC) == 2L)
stopifnot(is.numeric(b$BIC), length(b$BIC) == 2L)

# Explicit k, named, and reordered calls keep working through the dots.
stopifnot(identical(stats::AIC(m1, k = 3), stats::AIC(k = 3, object = m1)))
stopifnot(identical(stats::AIC(m1, m2, k = 2), stats::AIC(object = m1, m2, k = 2)))
stopifnot(identical(stats::BIC(m1), stats::BIC(object = m1)))
named_bic <- stats::BIC(m1, object2 = m2)
stopifnot(is.data.frame(named_bic), identical(names(named_bic), c('df', 'BIC')))

# BIC can return NA when the observation count cannot be established: a
# class with a logLik method but no nobs path gets NA from BIC.default's
# tryCatch fallback while AIC stays numeric on the same object.
logLik.ry_no_nobs <- function(object, ...) structure(-10, df = 2L, class = 'logLik')
no_nobs <- structure(list(), class = 'ry_no_nobs')
na_bic <- stats::BIC(no_nobs)
stopifnot(is.numeric(na_bic), length(na_bic) == 1L, is.na(na_bic))
na_aic <- stats::AIC(no_nobs)
stopifnot(is.numeric(na_aic), length(na_aic) == 1L, !is.na(na_aic))

# Control: $ on a genuine atomic vector really is an error.
err <- tryCatch((1:3)$x, error = conditionMessage)
stopifnot(grepl('atomic vector', err, fixed = TRUE))

cat('AIC/BIC single-model, multi-model, k, named, and BIC-NA controls passed\n')
