#!/usr/bin/env Rscript
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
doc <- jsonlite::read_json(file.path(root, "stubs/base/base.json"))
spec <- doc$functions$regmatches
declared <- vapply(spec$params, function(param) if (is.character(param)) param else param$name, character(1))
stopifnot(identical(spec$return, list(mode = "opaque", length = "unknown", na = TRUE)))
stopifnot(identical(unname(declared), names(formals(base::regmatches))))

x <- c("ab", "z")
single <- regmatches(x, regexpr("a", x))
captures <- regmatches(x, regexec("(a)(b)", x))
multiple <- regmatches(c("aa", "z"), gregexpr("a", c("aa", "z")))
stopifnot(identical(single, "a"))
stopifnot(identical(captures, list(c("ab", "a", "b"), character())))
stopifnot(identical(multiple, list(c("a", "a"), character())))
stopifnot(identical(lengths(captures), c(3L, 0L)))
stopifnot(identical(lengths(multiple), c(2L, 0L)))
stopifnot(length(Filter(function(z) length(z) > 0L, captures)) == 1L)
stopifnot(identical(vapply(multiple, function(z) length(z) == 0L, logical(1)), c(FALSE, TRUE)))

# Even vector match data returns a list when unmatched pieces are requested.
stopifnot(identical(regmatches("ab", regexpr("a", "ab"), invert = TRUE), list(c("", "b"))))
stopifnot(identical(regmatches("ab", regexpr("a", "ab"), invert = NA), list(c("", "a", "b"))))
cat("regmatches vector/list shapes and variable element lengths passed\n")
