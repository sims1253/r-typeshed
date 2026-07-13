#!/usr/bin/env Rscript

# Check that every stubbed function exists in its package namespace. Packages
# not installed locally are skipped. This base-R script extracts function keys
# from the stable, pretty-printed repository JSON without external packages.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else "."
stub_root <- normalizePath(file.path(script_dir, "..", "stubs"), mustWork = TRUE)

extract_names <- function(path) {
  lines <- readLines(path, warn = FALSE)
  start <- grep('^  "functions": \\{', lines)
  if (length(start) != 1L) stop("Could not locate functions in ", path)
  out <- character()
  for (line in lines[seq.int(start + 1L, length(lines))]) {
    if (grepl('^  \\}', line)) break
    match <- regmatches(line, regexec('^    "([^"]+)": \\{', line))[[1]]
    if (length(match) > 1L) out <- c(out, match[[2]])
  }
  out
}

failures <- character()
for (path in list.files(stub_root, pattern = "[.]json$", recursive = TRUE, full.names = TRUE)) {
  pkg <- basename(dirname(path))
  names <- extract_names(path)
  if (pkg == "base") {
    for (name in names) if (!exists(name, where = search(), inherits = TRUE)) {
      method <- tryCatch(utils::getS3method(sub("[.][^.]+$", "", name), sub("^.*[.]", "", name), optional = TRUE), error = function(e) NULL)
      if (is.null(method)) failures <- c(failures, paste0(pkg, "::", name))
    }
  } else if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("SKIP: package %s is not installed\n", pkg))
  } else {
    ns <- asNamespace(pkg)
    # Re-exports (dplyr::tibble, purrr::set_names) live in the package's
    # export list but not in its namespace environment itself.
    exported <- getNamespaceExports(pkg)
    for (name in names) {
      if (!exists(name, ns, inherits = FALSE) && !(name %in% exported)) {
        failures <- c(failures, paste0(pkg, "::", name))
      }
    }
  }
}
if (length(failures)) {
  cat("Names not found:\n", paste(failures, collapse = "\n"), "\n")
  quit(status = 1)
}
cat("All available package names verified.\n")
