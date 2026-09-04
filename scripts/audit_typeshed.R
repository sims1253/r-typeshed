#!/usr/bin/env Rscript

# Check that every stubbed function exists in its package namespace. Packages
# not installed locally are skipped. Function names are extracted from the
# stable, pretty-printed repository JSON without external packages; auditing
# the typed `datasets` values additionally requires jsonlite.

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

# Check one typed value entry against its live value. Every failure names the
# entry. Mode and length are required by the schema; a missing field is a
# reported failure instead of an opaque "missing value where TRUE/FALSE
# needed" error. The `na` check is deliberately one-directional: `na` is an
# optional field, `na: true` is the corpus-wide conservative upper bound (a
# declared-NA value that happens to hold no missing value is sound), and only
# `na: false` contradicted by an actual missing value is an error. A declared
# `class` vector must match the live `class()` exactly and in order; an
# absent field is skipped rather than read as "no class". Declared
# `columns` recurse through the same checks against the value's elements.
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
  any_na <- tryCatch(anyNA(value), error = function(cnd) NA)
  if (!is.null(spec$na) && identical(isTRUE(spec$na), FALSE) && identical(any_na, TRUE)) {
    failures <- c(failures, paste0(label, " is declared non-NA but contains NA"))
  }
  # A declared class vector must equal the live class() exactly, in order.
  # An absent field is skipped: the corpus convention records `class` only
  # when it differs from the typeof's implicit class (a plain double vector
  # has implicit class "numeric" and declares nothing), so absence is not a
  # claim of "no class".
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
    failures <- c(failures, check_value_spec(paste0(pkg, "::", name), value, values[[name]]))
  }
  failures
}

# Audit the base stub's datasets block. Its entries name ambient values from
# the default search path: some are base's own namespace constants (letters,
# pi), while the conventional datasets (mtcars, state.name) live in the
# datasets package. That package exports nothing through its export list;
# its objects sit in the namespace's lazy-data environment, reached via
# `.__NAMESPACE__.$lazydata` and checked with `inherits = FALSE` so the
# fallback cannot resolve names through the namespace's parent chain (where
# `lm`, `str`, or `read.csv` would otherwise answer). Attribute each entry
# to the environment that actually provides it, then run the same value
# checks as for any other package.
audit_base_values <- function(path) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("audit_typeshed.R requires jsonlite for typed values")
  doc <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  values <- doc$datasets %||% list()
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
    failures <- c(failures, audit_base_values(path))
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
