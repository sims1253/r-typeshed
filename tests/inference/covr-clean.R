# covr clean fixture: exported functions, colorblind_palette dataset, and
# curated returns check cleanly with zero diagnostics.
library(covr)
flag <- in_covr()
if (flag) {
  pal <- colorblind_palette
  nchar(pal)
}
cov <- code_coverage("f <- function(x) x + 1L", "f(1L)")
pct <- percent_coverage(cov) + 1.0
df <- tally_coverage(cov)
df$filename
