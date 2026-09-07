#!/usr/bin/env Rscript

# Check function names, parameter flags, and typed values against installed R
# packages. Packages not installed locally are skipped.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else "."
stub_root <- normalizePath(file.path(script_dir, "..", "stubs"), mustWork = TRUE)
source(file.path(script_dir, "param_optionality.R"))

if (!requireNamespace("jsonlite", quietly = TRUE)) stop("audit_typeshed.R requires jsonlite")

# Check declared facts only: na:true permits NA; an absent class makes no
# class claim. Column declarations recurse into list elements.
check_value_spec <- function(label, value, spec) {
  if (is.function(value)) return(paste0(label, " is callable but declared as a value"))
  if (is.null(spec$mode)) return(paste0(label, " declares no mode"))
  if (is.null(spec$length)) return(paste0(label, " declares no length"))
  failures <- character()
  concrete_modes <- c("character", "complex", "double", "integer", "list", "logical", "raw")
  if (isTRUE(spec$mode %in% concrete_modes) && !identical(typeof(value), spec$mode)) {
    failures <- c(failures, paste0(label, " mode differs"))
  }
  if (identical(spec$mode, "null") && !is.null(value)) {
    failures <- c(failures, paste0(label, " is not NULL"))
  }
  if (isTRUE(grepl("^[0-9]+$", spec$length)) && !identical(length(value), as.integer(spec$length))) {
    failures <- c(failures, paste0(label, " length differs"))
  }
  # Opaque package objects may be environments, for which anyNA() warns.
  # Inspect missingness only when the declaration makes a non-NA claim.
  if (!is.null(spec$na) && identical(isTRUE(spec$na), FALSE)) {
    any_na <- tryCatch(anyNA(value), error = function(cnd) NA)
    if (identical(any_na, TRUE)) {
      failures <- c(failures, paste0(label, " is declared non-NA but contains NA"))
    }
  }
  if (!is.null(spec$class) && !identical(unlist(spec$class), class(value))) {
    failures <- c(failures, paste0(label, " class differs"))
  }
  columns <- spec$columns
  if (!is.null(columns) && length(columns)) {
    if (!is.list(value)) {
      failures <- c(failures, paste0(label, " declares columns but the value is not a list"))
    } else {
      for (column in names(columns)) {
        if (!(column %in% names(value))) {
          failures <- c(failures, paste0(label, " declares a column `", column, "` the value does not have"))
          next
        }
        failures <- c(failures, check_value_spec(paste0(label, "$", column), value[[column]], columns[[column]]))
      }
    }
  }
  failures
}

# Audit typed package values against installed namespace exports. These entries
# use the legacy `datasets` field but may be exported constants as well as
# conventional datasets.
audit_package_values <- function(doc, pkg) {
  values <- doc$datasets
  if (!length(values)) return(character())
  exports <- getNamespaceExports(pkg)
  failures <- character()
  for (name in names(values)) {
    if (!(name %in% exports)) {
      failures <- c(failures, paste0(pkg, "::", name, " is not an exported value"))
      next
    }
    value <- tryCatch(getExportedValue(pkg, name), error = function(cnd) cnd)
    if (inherits(value, "error")) {
      failures <- c(failures, paste0(pkg, "::", name, " export cannot be resolved"))
      next
    }
    failures <- c(failures, check_value_spec(paste0(pkg, "::", name), value, values[[name]]))
  }
  failures
}

# Base datasets include constants and the datasets namespace's lazy data.
# Do not inherit from parent environments when resolving either inventory.
audit_base_values <- function(doc) {
  values <- doc$datasets
  if (!length(values)) return(character())
  base_ns <- asNamespace("base")
  datasets_lazydata <- asNamespace("datasets")$.__NAMESPACE__.$lazydata
  failures <- character()
  for (name in names(values)) {
    if (exists(name, envir = base_ns, inherits = FALSE)) {
      home <- "base"
      value <- get(name, envir = base_ns, inherits = FALSE)
    } else if (exists(name, envir = datasets_lazydata, inherits = FALSE)) {
      home <- "datasets"
      value <- get(name, envir = datasets_lazydata, inherits = FALSE)
    } else {
      failures <- c(failures, paste0("base datasets entry ", name, " is provided by neither base nor datasets"))
      next
    }
    failures <- c(failures, check_value_spec(paste0(home, "::", name, " (base datasets entry)"), value, values[[name]]))
  }
  failures
}

find_base_function <- function(name) {
  for (pkg in c("base", "stats", "utils", "graphics", "grDevices", "methods")) {
    ns <- asNamespace(pkg)
    if (exists(name, envir = ns, inherits = FALSE)) {
      value <- get(name, envir = ns, inherits = FALSE)
      if (is.function(value)) return(value)
    }
  }
  NULL
}

# These wrappers and generics forward dots to the named implementation.
# The allowed names are read from that implementation's real formals.
forwarded_formals <- c(
  aov = "lm", cor.test = "cor.test.formula", cut = "cut.default",
  head = "head.default", ks.test = "ks.test.default", lag = "lag.default",
  mood.test = "mood.test.default", seq = "seq.default", subset = "subset.data.frame",
  t.test = "t.test.formula", tail = "tail.default", update = "update.default",
  var.test = "var.test.default", wilcox.test = "wilcox.test.formula",
  window = "window.default", write.csv = "write.table"
)

audit_base_formals <- function(doc) {
  first_category <- character()
  reverse_category <- character()
  name_mismatches <- character()
  forwarded_names <- character()
  skipped_primitives <- character()
  missing_optional_not_default <- character()
  stub_params <- lapply(doc$functions, function(sig) sig$params)
  for (fn_name in names(stub_params)) {
    fn <- find_base_function(fn_name)
    if (is.null(fn)) next
    fs <- formals(fn)
    if (is.null(fs)) {
      skipped_primitives <- c(skipped_primitives, fn_name)
      next
    }
    optional_params <- missing_optional_params(fn, names(fs)[names(fs) != "..."])
    for (param in stub_params[[fn_name]]) {
      if (is.character(param)) param <- list(name = param)
      if (!(param$name %in% names(fs))) {
        target <- unname(forwarded_formals[fn_name])
        forwarded <- "..." %in% names(fs) && !is.na(target) &&
          param$name %in% names(formals(find_base_function(target)))
        label <- paste0(fn_name, "::", param$name)
        if (forwarded) forwarded_names <- c(forwarded_names, label)
        else name_mismatches <- c(name_mismatches, label)
        next
      }
      has_default <- param$name == "..." || !identical(fs[[param$name]], quote(expr = ))
      if (has_default && isTRUE(param$required)) {
        first_category <- c(first_category, paste0(fn_name, "::", param$name))
      }
      if (!has_default && isTRUE(param$default)) {
        if (!(param$name %in% optional_params)) {
          reverse_category <- c(reverse_category, paste0(fn_name, "::", param$name))
        }
      }
      if (!has_default && !isTRUE(param$default) && param$name %in% optional_params) {
        missing_optional_not_default <- c(missing_optional_not_default, paste0(fn_name, "::", param$name))
      }
    }
  }
  report <- function(label, values) {
    cat(label, " (", length(values), "):\n", sep = "")
    if (length(values)) cat(paste0("  ", values, collapse = "\n"), "\n", sep = "")
  }
  report("Required despite R default/dots", first_category)
  report("Default despite required R formal", reverse_category)
  report("Missing()/maybe_missing()/nargs()-optional but not default", missing_optional_not_default)
  report("Invalid formal names", name_mismatches)
  report("Reviewed forwarded formals", forwarded_names)
  report("Primitives without formals", skipped_primitives)
  invisible(list(
    required_with_default = first_category,
    default_on_required = reverse_category,
    missing_optional_not_default = missing_optional_not_default,
    name_mismatches = name_mismatches,
    failures = c(first_category, reverse_category, name_mismatches),
    forwarded_names = forwarded_names,
    skipped_primitives = skipped_primitives
  ))
}

if ("--base-formals-only" %in% commandArgs(trailingOnly = TRUE)) {
  report <- audit_base_formals(jsonlite::read_json(file.path(stub_root, "base", "base.json")))
  quit(status = as.integer(length(report$failures) > 0L))
}

failures <- character()
for (path in list.files(stub_root, pattern = "[.]json$", recursive = TRUE, full.names = TRUE)) {
  doc <- jsonlite::read_json(path)
  pkg <- doc$package
  if (!is.character(pkg) || length(pkg) != 1L || !nzchar(pkg)) stop(path, ": requires a package name", call. = FALSE)
  if (is.null(doc$functions) || !is.list(doc$functions)) stop(path, ": requires a functions object", call. = FALSE)
  names <- names(doc$functions)
  if (pkg == "base") {
    for (name in names) if (!exists(name, where = search(), inherits = TRUE)) {
      method <- tryCatch(utils::getS3method(sub("[.][^.]+$", "", name), sub("^.*[.]", "", name), optional = TRUE), error = function(e) NULL)
      if (is.null(method)) failures <- c(failures, paste0(pkg, "::", name))
    }
    failures <- c(failures, audit_base_values(doc))
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
    failures <- c(failures, audit_package_values(doc, pkg))
  }
}
if (length(failures)) {
  cat("Names not found:\n", paste(failures, collapse = "\n"), "\n")
  quit(status = 1)
}
cat("All available package names verified.\n")
report <- audit_base_formals(jsonlite::read_json(file.path(stub_root, "base", "base.json")))
if (length(report$failures)) quit(status = 1)
