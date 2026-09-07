#!/usr/bin/env Rscript
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
doc <- jsonlite::read_json(file.path(root, "stubs/base/base.json"))
spec <- doc$functions$confint
stopifnot(identical(spec$return, list(mode = "opaque", length = "unknown", na = TRUE)))
stopifnot(identical(unlist(spec$params), names(formals(stats::confint))))

stopifnot(identical(names(formals(stats::confint)), c('object', 'parm', 'level', '...')))
confint.ry_contract <- function(object, parm, level = 0.95, ...) {
  list(interval = c(-1, 1), estimate = NA_real_, level = level)
}
x <- structure(list(), class = 'ry_contract')
y <- stats::confint(x, level = .9)
stopifnot(is.list(y), identical(y$interval, c(-1, 1)), is.na(y$estimate), identical(y$level, .9))
fit <- lm(y ~ x + z, data = data.frame(y = c(1, 3, 2, 5), x = 1:4, z = 2*(1:4)))
ci <- stats::confint(fit)
stopifnot(is.matrix(ci), is.double(ci), anyNA(ci))
cat('confint live formals, dispatched list, and missing matrix controls passed\n')
