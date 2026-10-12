#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: these selections keep the first argument's mode and class
# (`return: "arg0"`) but re-count its elements, so only an empty input
# proves the result length. Flip any pinned field and this test must fail.
rule <- function(kind, ...) list(kind = kind, params = list(...))
for (name in c('head', 'tail', 'unique', 'setdiff', 'window')) {
  stopifnot(identical(base[[name]]$return, 'arg0'),
            identical(base[[name]]$return_length, rule('zero_if_any_param_zero', 'x')))
}
stopifnot(identical(base$na.omit$return_length, rule('zero_if_any_param_zero', 'object')))
stopifnot(identical(base$intersect$return_length, rule('zero_if_any_param_zero', 'x', 'y')))
stopifnot(identical(base$union$return, 'arg0'),
          identical(base$union$return_length, rule('zero_if_all_params_zero', 'x', 'y')))
stopifnot(identical(base$subset$return, 'arg0'),
          identical(base$subset$return_length, rule('zero_if_all_params_zero', 'x', 'subset')))

# Live-R witnesses: the result length is not the first argument's.
x <- c(3, 1, 2)
stopifnot(identical(head(x, 1), 3), identical(tail(x, 1), 2))
stopifnot(identical(unique(c(5, 5)), 5))
stopifnot(identical(setdiff(c(1, 2, 3), c(2, 3)), 1))
stopifnot(identical(union(c(1, 1), 1), 1), identical(length(union(1, 2)), 2L))
stopifnot(identical(length(na.omit(c(1, NA))), 1L))
stopifnot(identical(subset(x, x > 2), 3))
stopifnot(identical(length(window(ts(1:10), 1, 1)), 1L))

# An empty input empties the result. union needs both inputs empty, and
# subset both its vector and its condition: a TRUE condition recycles
# against nothing and selects one NA.
stopifnot(identical(head(character(0), 3), character(0)))
stopifnot(identical(tail(integer(0), 3), integer(0)))
stopifnot(identical(unique(numeric(0)), numeric(0)))
stopifnot(identical(setdiff(numeric(0), 1), numeric(0)))
stopifnot(identical(subset(numeric(0), logical(0)), numeric(0)))
stopifnot(identical(subset(numeric(0), TRUE), NA_real_))
stopifnot(identical(length(na.omit(numeric(0))), 0L))
stopifnot(identical(length(union(numeric(0), numeric(0))), 0L))
stopifnot(identical(union(numeric(0), 1), 1))

# Class carries over; a data frame keeps its columns (and so its length)
# while the selection changes its row count.
f <- factor(c('a', 'b', 'a'))
stopifnot(inherits(head(f, 1), 'factor'), inherits(unique(f), 'factor'))
df <- data.frame(a = 1:3, b = c('x', 'y', 'z'))
stopifnot(identical(names(head(df, 2)), names(df)), identical(length(head(df, 2)), 2L))
stopifnot(identical(nrow(head(df, 2)), 2L), identical(nrow(unique(df[c(1, 1), ])), 1L))

cat('selection lengths: arg0 mode and class, re-counted elements passed\n')
