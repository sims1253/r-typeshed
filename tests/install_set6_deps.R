#!/usr/bin/env Rscript
# Install the archived versions used by the set6 inventory test.
versions <- c(ooplah = "0.2.0", dictionar6 = "0.1.3", set6 = "0.2.4")
lib <- .libPaths()[[1L]]
for (pkg in names(versions)) {
  version <- versions[[pkg]]
  installed <- tryCatch(as.character(packageVersion(pkg, lib.loc = lib)),
                        error = function(e) NA_character_)
  if (!identical(installed, version)) {
    url <- sprintf("https://cran.r-project.org/src/contrib/Archive/%s/%s_%s.tar.gz",
                   pkg, pkg, version)
    install.packages(url, repos = NULL, type = "source", lib = lib)
  } else {
    message("Using cached ", pkg, " ", version)
  }
  stopifnot(identical(as.character(packageVersion(pkg, lib.loc = lib)), version))
  loadNamespace(pkg, lib.loc = lib)
}
