#!/usr/bin/env Rscript
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
doc <- jsonlite::read_json(file.path(root, "stubs/base/base.json"))
spec <- doc$functions$grep
stopifnot(identical(spec$return, list(mode = "opaque", length = "unknown", na = TRUE)))
stopifnot(identical(unlist(spec$params), names(formals(base::grep))))

x <- c("Apple", "banana", NA_character_, "pear")
stopifnot(identical(grep("a", x), c(2L, 4L)))
stopifnot(identical(grep("a", x, value = FALSE), c(2L, 4L)))
stopifnot(identical(grep("a", x, value = TRUE), c("banana", "pear")))
stopifnot(identical(grep("a", x, FALSE, FALSE, TRUE), c("banana", "pear")))
stopifnot(identical(grep("a", x, val = TRUE), c("banana", "pear")))
stopifnot(identical(grep("a", x, value = 1L), c("banana", "pear")))
stopifnot(identical(grep("a", x, ignore.case = TRUE), c(1L, 2L, 4L)))
stopifnot(identical(grep("a", x, value = TRUE, invert = TRUE), c("Apple", NA_character_)))
stopifnot(identical(grep(NA_character_, x), rep(NA_integer_, length(x))))
stopifnot(identical(grep(NA_character_, x, value = TRUE), rep(NA_character_, length(x))))
stopifnot(identical(grep("z", x), integer()))
stopifnot(identical(grep("z", x, value = TRUE), character()))
stopifnot(identical(grep("2", c(12L, 3L), value = TRUE), "12"))
stopifnot(identical(grep("a", factor(c("a", "b")), value = TRUE), "a"))
# grep dispatches as.character() from base, so register the test method where
# S3 lookup can find it rather than in a local caller frame.
as.character.ry_grep_contract <- function(x, ...) c("match", "other")
values <- structure(c(1L, 2L), class = "ry_grep_contract")
stopifnot(identical(grep("match", values, value = TRUE), "match"))
rm(as.character.ry_grep_contract, values)
# The documented index result is double for long-vector inputs; this test
# deliberately does not allocate or scan a vector larger than .Machine$integer.max.
cat("grep formals, value controls, missing values, and input coercion verified.\n")
