#!/usr/bin/env Rscript

# Check that every stubbed function exists in its package namespace. Packages
# not installed locally are skipped. This base-R script extracts function keys
# from the stable, pretty-printed repository JSON without external packages.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else "."
stub_root <- normalizePath(file.path(script_dir, "..", "stubs"), mustWork = TRUE)
source(file.path(script_dir, "param_optionality.R"))

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

`%||%` <- function(left, right) if (is.null(left)) right else left

# Audit typed package values against installed namespace exports. These entries
# use the legacy `datasets` field but may be exported constants as well as
# conventional datasets.
audit_package_values <- function(path, pkg) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("audit_typeshed.R requires jsonlite for typed values")
  doc <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  values <- doc$datasets %||% list()
  if (!length(values) || !requireNamespace(pkg, quietly = TRUE)) return(character())
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
    spec <- values[[name]]
    if (is.function(value)) failures <- c(failures, paste0(pkg, "::", name, " is callable but declared as a value"))
    concrete_modes <- c("character", "complex", "double", "integer", "list", "logical", "raw")
    if (spec$mode %in% concrete_modes && !identical(typeof(value), spec$mode)) {
      failures <- c(failures, paste0(pkg, "::", name, " mode differs"))
    }
    if (identical(spec$mode, "null") && !is.null(value)) {
      failures <- c(failures, paste0(pkg, "::", name, " is not NULL"))
    }
    if (grepl("^[0-9]+$", spec$length) && !identical(length(value), as.integer(spec$length))) {
      failures <- c(failures, paste0(pkg, "::", name, " length differs"))
    }
    if (!is.null(spec$na) && !identical(anyNA(value), isTRUE(spec$na))) {
      failures <- c(failures, paste0(pkg, "::", name, " NA metadata differs"))
    }
  }
  failures
}

# Audit the base stub's parameter flags against the actual formals.  This is
# deliberately a small, dependency-free reader for the repository's
# pretty-printed JSON: it only needs function names and their params arrays.
count_chars <- function(x, char) {
  matches <- gregexpr(char, x, fixed = TRUE)[[1]]
  sum(matches > 0L)
}

extract_base_params <- function(path) {
  lines <- readLines(path, warn = FALSE)
  start <- grep('^  "functions": \\{', lines)
  if (length(start) != 1L) stop("Could not locate functions in ", path)
  out <- list()
  i <- start + 1L
  while (i <= length(lines) && !grepl('^  \\}', lines[[i]])) {
    key <- regmatches(lines[[i]], regexec('^    "([^"]+)": \\{', lines[[i]]))[[1]]
    if (length(key) <= 1L) {
      i <- i + 1L
      next
    }
    name <- key[[2]]
    depth <- count_chars(lines[[i]], "{") - count_chars(lines[[i]], "}")
    end <- i
    while (depth > 0L && end < length(lines)) {
      end <- end + 1L
      depth <- depth + count_chars(lines[[end]], "{") - count_chars(lines[[end]], "}")
    }
    block <- lines[i:end]
    params_line <- grep('^      "params": \\[', block)
    params <- list()
    if (length(params_line) == 1L && !grepl('\\[\\]', block[[params_line]])) {
      j <- params_line + 1L
      while (j <= length(block) && !grepl('^      \\]', block[[j]])) {
        bare <- regmatches(block[[j]], regexec('^        "([^"]+)"[,]?$', block[[j]]))[[1]]
        if (length(bare) > 1L) {
          params[[length(params) + 1L]] <- list(name = bare[[2]], required = FALSE, default = FALSE)
          j <- j + 1L
          next
        }
        if (grepl('^        \\{', block[[j]])) {
          param_start <- j
          param_depth <- count_chars(block[[j]], "{") - count_chars(block[[j]], "}")
          while (param_depth > 0L && j < length(block)) {
            j <- j + 1L
            param_depth <- param_depth + count_chars(block[[j]], "{") - count_chars(block[[j]], "}")
          }
          param <- block[param_start:j]
          field <- function(field_name) any(grepl(paste0('"', field_name, '": true'), param, fixed = TRUE))
          param_name <- regmatches(param, regexec('"name": "([^"]+)"', param))
          param_name <- unlist(param_name, use.names = FALSE)
          if (length(param_name) >= 2L) {
            params[[length(params) + 1L]] <- list(
              name = param_name[[2]], required = field("required"), default = field("default")
            )
          }
        }
        j <- j + 1L
      }
    }
    out[[name]] <- params
    i <- end + 1L
  }
  out
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

audit_base_formals <- function(path) {
  first_category <- character()
  reverse_category <- character()
  name_mismatches <- character()
  skipped_primitives <- character()
  missing_optional_not_default <- character()
  stub_params <- extract_base_params(path)
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
      if (!(param$name %in% names(fs))) {
        name_mismatches <- c(name_mismatches, paste0(fn_name, "::", param$name))
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
  report("Stub params missing from R formals", name_mismatches)
  report("Primitives without formals", skipped_primitives)
  invisible(list(
    required_with_default = first_category,
    default_on_required = reverse_category,
    missing_optional_not_default = missing_optional_not_default,
    name_mismatches = name_mismatches,
    skipped_primitives = skipped_primitives
  ))
}

if ("--base-formals-only" %in% commandArgs(trailingOnly = TRUE)) {
  audit_base_formals(file.path(stub_root, "base", "base.json"))
  quit(status = 0)
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
    failures <- c(failures, audit_package_values(path, pkg))
  }
}
if (length(failures)) {
  cat("Names not found:\n", paste(failures, collapse = "\n"), "\n")
  quit(status = 1)
}
cat("All available package names verified.\n")
audit_base_formals(file.path(stub_root, "base", "base.json"))
