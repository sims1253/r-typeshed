#!/usr/bin/env Rscript
# Install the archived versions used by the set6 inventory test.
versions <- c(ooplah = "0.2.0", dictionar6 = "0.1.3", set6 = "0.2.4")
for (pkg in names(versions)) {
  version <- versions[[pkg]]
  url <- sprintf("https://cran.r-project.org/src/contrib/Archive/%s/%s_%s.tar.gz",
                 pkg, pkg, version)
  install.packages(url, repos = NULL, type = "source", lib = .libPaths()[[1L]])
  stopifnot(identical(as.character(packageVersion(pkg, lib.loc = .libPaths()[[1L]])), version))
  loadNamespace(pkg)
}
