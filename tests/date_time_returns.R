#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: Sys.Date() returns a classed "Date" and Sys.time() a classed
# c("POSIXct", "POSIXt"), both on double storage; date() is a plain string.
# Flip any pinned field and this test must fail.
stopifnot(identical(base$Sys.Date$return,
                    list(mode = 'double', length = '1', na = FALSE, class = list('Date'))))
stopifnot(identical(base$Sys.time$return,
                    list(mode = 'double', length = '1', na = FALSE,
                         class = list('POSIXct', 'POSIXt'))))
stopifnot(identical(base$date$return, list(mode = 'character', length = '1', na = FALSE)))

# Live-R witnesses.
d <- Sys.Date()
stopifnot(identical(class(d), 'Date'), is.double(d), identical(length(d), 1L), !is.na(d))
t <- Sys.time()
stopifnot(identical(class(t), c('POSIXct', 'POSIXt')), is.double(t),
          identical(length(t), 1L), !is.na(t))
s <- date()
stopifnot(identical(class(s), 'character'), identical(length(s), 1L), !is.na(s))
# The class is what callers observe: is.numeric() has Date and POSIXt
# methods that return FALSE, and neither class has a `$` method, so `$`
# still fails as on any atomic vector.
stopifnot(!is.numeric(d), !is.numeric(t), is.numeric(unclass(d)))
for (value in list(d, t)) {
  msg <- tryCatch({ value$x; '' }, error = conditionMessage)
  stopifnot(grepl('invalid for atomic vectors', msg, fixed = TRUE))
}
cat('Sys.Date, Sys.time, and date return controls passed\n')
