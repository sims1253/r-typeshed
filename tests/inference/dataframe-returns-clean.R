# The read.table family returns data frames, merge() is opaque, and gc()
# returns a double matrix, so column arithmetic on their results is valid
# (sims1253/ry#709): a column vector, Ops.data.frame, and a matrix column.
f <- function(a, b) {
  m <- merge(a, b, by = 1)
  m[, 1] - 1
}
one <- function(a) merge(a, a)[1] + 1
g <- function(path) {
  m <- read.csv(path)
  100 * m[, c("x", "y")]
}
t1 <- function(path) read.table(path, header = TRUE)[, 1] + 1
t2 <- function(path) read.delim(path)[, 1] + 1
t3 <- function(path) read.csv2(path)[, 1] + 1
t4 <- function(path) read.delim2(path)[, 1] + 1
h <- function() sum(gc()[, 1] * c(56, 8))
