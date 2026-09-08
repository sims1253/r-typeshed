#!/usr/bin/env Rscript
# mirai::status() returns a named list, not an integer: verify the stub
# contract against the installed package before syncing it into ry.
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
sig <- jsonlite::read_json(file.path(root, 'stubs/mirai/mirai.json'))$functions$status

library(mirai)
stopifnot(identical(unlist(sig$params), '.compute'))
stopifnot(identical(names(formals(mirai::status)), '.compute'))
stopifnot(identical(sig$return$mode, 'list'))

# Runtime shape: named list; connections/daemons always present.
daemons(1, sync = TRUE)
status_value <- status()
on.exit(daemons(0), add = TRUE)
stopifnot(is.list(status_value), identical(names(status_value)[1], 'connections'))
stopifnot(is.integer(status_value$connections), is.character(status_value$daemons))
# A dollar access on the result must be valid R.
stopifnot(is.integer(status_value$connections))
