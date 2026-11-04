#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Result modes that `double_or_int` got wrong (#124, #126). Consumers
# resolve `double_or_int` to integer for integer input, so these entries
# claimed integer for mean(1:3) and the like. Flip any pinned field and
# this test must fail.
returns <- list(
  mean = list(mode = 'union', length = '1',
              members = list('double', 'complex'), na = TRUE),
  prod = list(mode = 'union', length = '1',
              members = list('double', 'complex'), na = TRUE),
  round = list(mode = 'union', length = 'arg0',
               members = list('double', 'complex'), na = TRUE),
  cumprod = list(mode = 'union', length = 'arg0',
                 members = list('double', 'complex'), na = TRUE),
  sign = list(mode = 'double', length = 'arg0', na = TRUE),
  seq = list(mode = 'union', length = 'unknown',
             members = list('integer', 'double'), na = FALSE),
  seq.int = list(mode = 'union', length = 'unknown',
                 members = list('integer', 'double'), na = FALSE),
  sample = list(mode = 'opaque', length = 'unknown', na = TRUE),
  ave = list(mode = 'opaque', length = 'arg0', na = TRUE)
)
for (entry in names(returns)) {
  stopifnot(identical(base[[entry]]$return, returns[[entry]]))
}

mode_of <- function(f, ...) typeof(f(...))
errors <- function(expr) {
  inherits(tryCatch(expr, error = function(e) e), 'error')
}

# #124: mean, prod, round, and cumprod never return integer. Logical,
# integer, and double input give double; complex input gives complex.
for (f in list(mean, prod, round, cumprod)) {
  stopifnot(identical(mode_of(f, TRUE), 'double'))
  stopifnot(identical(mode_of(f, 1:3), 'double'))
  stopifnot(identical(mode_of(f, 1L), 'double'))
  stopifnot(identical(mode_of(f, 1.5), 'double'))
  stopifnot(identical(mode_of(f, 1i), 'complex'))
}
stopifnot(identical(length(cumprod(1:3)), 3L), identical(length(round(1:3)), 3L))
stopifnot(identical(length(mean(1:3)), 1L), identical(length(prod(1:3)), 1L))
# round now shares signif's contract, including missingness (#129).
stopifnot(anyNA(round(c(1.5, NA))))

# sign is double for every input it accepts and rejects complex.
stopifnot(identical(mode_of(sign, TRUE), 'double'))
stopifnot(identical(mode_of(sign, 1L), 'double'))
stopifnot(identical(mode_of(sign, 1.5), 'double'))
stopifnot(errors(sign(1i)))

# #126: seq and seq.int return integer or double depending on argument
# values, not on argument modes, so neither member can be dropped.
stopifnot(identical(typeof(seq(1, 10)), 'integer'))
stopifnot(identical(typeof(seq.int(1, 10)), 'integer'))
stopifnot(identical(typeof(seq(5)), 'integer'))
stopifnot(identical(typeof(seq.int(2)), 'integer'))
stopifnot(identical(typeof(seq(1, 10, by = 2)), 'double'))
stopifnot(identical(typeof(seq(2, 8, length.out = 4)), 'double'))
stopifnot(identical(typeof(seq(1.5, 3)), 'double'))

# sample() permutes seq_len(x) when x is a single number >= 1, and
# otherwise samples the elements of x, so its mode follows neither rule
# alone. The return stays opaque until a rule can express that.
stopifnot(identical(typeof(sample(10)), 'integer'))
stopifnot(identical(typeof(sample(2.5)), 'integer'))
stopifnot(identical(typeof(sample(c(1.5, 2))), 'double'))
stopifnot(identical(typeof(sample(letters, 2)), 'character'))
stopifnot(identical(class(sample(factor(c('a', 'b')))), 'factor'))

# ave() assigns FUN's results back into x, so the result mode is FUN's,
# while the length stays length(x).
stopifnot(identical(typeof(ave(1:3)), 'double'))
stopifnot(identical(typeof(ave(1:3, FUN = length)), 'integer'))
stopifnot(identical(typeof(ave(1:3, FUN = as.character)), 'character'))
stopifnot(identical(length(ave(1:3, FUN = as.character)), 3L))
stopifnot(identical(length(ave(1:4, c(1, 1, 2, 2), FUN = length)), 4L))

cat('value-dependent and non-integer result modes passed\n')
