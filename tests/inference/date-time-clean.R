# Sys.Date() returns a "Date" and Sys.time() a c("POSIXct", "POSIXt"), so
# is.numeric() is FALSE for both and these branches never run in R. A
# class-less double made the dead `$` accesses look reachable.
f <- function() {
  x <- Sys.Date()
  if (is.numeric(x)) x$y else format(x, "%Y")
}
g <- function() {
  t <- Sys.time()
  if (is.numeric(t)) t$y
}
h <- function() {
  x <- Sys.Date()
  if (!inherits(x, "Date")) x$y
}
