#!/usr/bin/env Rscript
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
doc <- jsonlite::read_json(file.path(root, "stubs/base/base.json"))
spec <- doc$functions$sort.int
stopifnot(identical(spec$return, list(mode = "opaque", length = "unknown", na = TRUE)))
declared <- vapply(spec$params, function(param) if (is.character(param)) param else param$name, character(1))
stopifnot(identical(unname(declared), names(formals(base::sort.int))))

stopifnot(identical(sort.int(c(2L, NA_integer_, 1L)), c(1L, 2L)))
stopifnot(identical(sort.int(c("b", "a")), c("a", "b")))
indexed <- sort.int(c(2, 1), method = "quick", index.return = TRUE)
stopifnot(identical(indexed, list(x = c(1, 2), ix = c(2L, 1L))))
radix <- sort.int(c(3, NA, 1, 3), method = "radix", index.return = TRUE)
stopifnot(identical(radix, list(x = c(1, 3, 3), ix = c(2L, 1L, 3L))))
cat("sort.int atomic and indexed list return controls passed\n")
