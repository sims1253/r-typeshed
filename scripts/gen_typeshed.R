#!/usr/bin/env Rscript

# Emit a draft stub for an installed R package. The output includes the
# schema_version and package headers required by r-typeshed. It is a curation
# aid only: return types must be reviewed by a human.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else "."
source(file.path(script_dir, "param_optionality.R"))

escape_json <- function(x) {
  x <- gsub("\\", "\\\\", x, fixed = TRUE)
  gsub('"', '\\"', x, fixed = TRUE)
}

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
  funs <- exports[vapply(exports, function(x) exists(x, ns, mode = "function", inherits = FALSE), logical(1))]
  entries <- vapply(funs, function(name) {
    fn <- get(name, ns)
    fm <- tryCatch(formals(fn), error = function(e) NULL)
    params <- if (is.null(fm)) character() else names(fm)
    keep <- nzchar(params)
    params <- params[keep]
    formal_values <- if (is.null(fm)) pairlist() else fm[keep]
    optional_params <- missing_optional_params(fn, params[params != "..."])
    quoted <- vapply(seq_along(params), function(i) {
      escaped <- escape_json(params[[i]])
      missing_default <- identical(unname(formal_values[i]), unname(alist(value = )[1]))
      required <- params[[i]] != "..." && missing_default && !(params[[i]] %in% optional_params)
      if (required) sprintf('{"name": "%s", "required": true}', escaped) else sprintf('"%s"', escaped)
    }, character(1))
    sprintf('    "%s": {\n      "params": [%s],\n      "return": {"mode": "opaque", "length": "unknown", "na": false}\n    }',
            escape_json(name), paste(quoted, collapse = ", "))
  }, character(1))
  cat(sprintf('{\n  "schema_version": "1",\n  "package": "%s",\n  "version": "draft",\n  "functions": {\n%s\n  }\n}\n',
              escape_json(pkg), paste(entries, collapse = ",\n")))
  message(sprintf("Generated %d draft function entries for '%s'.", length(funs), pkg))
}

main(commandArgs(trailingOnly = TRUE))
