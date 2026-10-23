# cut() is an S3 generic, and cut.dendrogram() returns list(upper =,
# lower =) (sims1253/ry#711), so `$` on the result of cut() on a
# receiver that may be a dendrogram is valid.
f <- function(dend, h) cut(dend, h = h)$lower
g <- function(hc, th) cut(stats::as.dendrogram(hc), h = th)$upper
