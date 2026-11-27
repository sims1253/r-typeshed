# Pin curated covr return and dataset types via dump-types.
flag <- covr::in_covr()
pal <- covr::colorblind_palette
pct <- covr::percent_coverage(covr::code_coverage("f <- function(x) x", "f(1)"))
tally <- covr::tally_coverage(covr::code_coverage("f <- function(x) x", "f(1)"))
