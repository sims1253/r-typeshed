#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
base <- jsonlite::read_json(file.path(root, 'stubs/base/base.json'))$functions

# Stub pins: the read.table family returns a data frame, merge() is an S3
# generic whose methods outside base return other shapes (zoo, dendrogram),
# so its return stays opaque, and gc() returns a double matrix that may hold
# NA limits. Flip any pinned field and this test must fail.
data_frame <- list(mode = 'list', length = 'unknown', na = TRUE, class = list('data.frame'))
readers <- c('read.table', 'read.csv', 'read.csv2', 'read.delim', 'read.delim2')
for (name in readers) stopifnot(identical(base[[name]]$return, data_frame))
stopifnot(identical(base$merge$return, list(mode = 'opaque', length = 'unknown', na = TRUE)))
stopifnot(identical(base$gc$return, list(mode = 'double', length = 'unknown', na = TRUE,
                                         class = list('matrix', 'array'))))

# Live-R witnesses.
path <- tempfile(fileext = '.csv')
on.exit(unlink(path))
writeLines(c('x,y', '1,2', '3,4'), path)
for (name in readers) {
  frame <- match.fun(name)(path, header = TRUE, sep = ',', dec = '.')
  stopifnot(identical(class(frame), 'data.frame'))
}
a <- data.frame(k = 1:2, v = c(3, 4))
m <- merge(a, data.frame(k = 2:3, w = c(5, 6)))
stopifnot(identical(class(m), 'data.frame'), identical(m[, 1] - 1, 1), is.data.frame(m[1] + 1))
# merge.default coerces with as.data.frame(), but registered methods return
# their own class, so the generic cannot promise a data frame.
stopifnot(identical(class(merge(1:2, 3:4)), 'data.frame'))
stopifnot(inherits(merge(stats::as.dendrogram(hclust(dist(1:3))),
                         stats::as.dendrogram(hclust(dist(4:6)))), 'dendrogram'))
g <- gc()
stopifnot(is.matrix(g), is.double(g), identical(class(g), c('matrix', 'array')))
stopifnot(is.double(g[, 1] * c(56, 8)))
# A configured memory limit is reported as a "limit (Mb)" column whose
# unset entry is NA.
limited <- system2(file.path(R.home('bin'), 'Rscript'),
                   c('--vanilla', '-e', shQuote('cat(anyNA(gc()))')),
                   stdout = TRUE, env = 'R_MAX_VSIZE=4Gb')
stopifnot(identical(limited, 'TRUE'))
cat('read.table family, merge, and gc return controls passed\n')
