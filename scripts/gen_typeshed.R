#!/usr/bin/env Rscript

# Emit a draft stub for an installed R package. The output includes the
# schema_version and package headers required by r-typeshed. It is a curation
# aid only: return types must be reviewed by a human.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else "."
source(file.path(script_dir, "param_optionality.R"))

if (!requireNamespace("jsonlite", quietly = TRUE)) stop("gen_typeshed.R requires jsonlite")

main <- function(argv) {
  if (length(argv) < 1L || argv[[1]] %in% c("--help", "-h")) {
    cat("Usage: Rscript scripts/gen_typeshed.R <package>\n")
    return(invisible())
  }
  pkg <- argv[[1]]
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("Package '%s' is not installed; install it first.", pkg))
    quit(status = 1)
  }
  ns <- asNamespace(pkg)
  exports <- sort(getNamespaceExports(ns))
  funs <- exports[vapply(exports, function(name) is.function(getExportedValue(pkg, name)), logical(1))]
  entries <- lapply(funs, function(name) {
    fn <- getExportedValue(pkg, name)
    fm <- formals(fn)
    params <- names(fm)
    optional_params <- missing_optional_params(fn, setdiff(params, "..."))
    params <- lapply(params, function(name) {
      required <- name != "..." && identical(fm[[name]], quote(expr = )) && !(name %in% optional_params)
      if (required) list(name = name, required = TRUE) else name
    })
    list(params = params, "return" = list(mode = "opaque", length = "unknown", na = TRUE))
  })
  doc <- list(schema_version = "2", package = pkg, version = "draft",
              functions = setNames(entries, funs))
  cat(jsonlite::toJSON(doc, auto_unbox = TRUE, pretty = TRUE), "\n")
  message(sprintf("Generated %d draft function entries for '%s'.", length(funs), pkg))
}

main(commandArgs(trailingOnly = TRUE))
