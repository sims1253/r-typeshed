#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
if (length(args) == 0L) {
  stop("usage: Rscript --vanilla scripts/gen_nse_metadata.R <package> [...]", call. = FALSE)
}

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("the jsonlite package is required", call. = FALSE)
}

script_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
if (length(script_arg) != 1L) {
  stop("could not determine the script path", call. = FALSE)
}
script_path <- normalizePath(sub("^--file=", "", script_arg), mustWork = TRUE)
repo_root <- dirname(dirname(script_path))

rd_text <- function(node) {
  paste(unlist(node, recursive = TRUE, use.names = FALSE), collapse = "")
}

rd_sections <- function(rd, tag) {
  Filter(function(node) identical(attr(node, "Rd_tag"), tag), rd)
}

argument_modes <- function(rd) {
  modes <- list()
  for (section in rd_sections(rd, "\\arguments")) {
    items <- Filter(
      function(node) identical(attr(node, "Rd_tag"), "\\item"),
      section
    )
    for (item in items) {
      description <- rd_text(item[[2L]])
      # tidyselect 1.2.1 and dplyr's superseded do() page predate the
      # roxygen markers used by current tidyverse packages. Their canonical
      # descriptions are equally explicit, so retain these narrow fallbacks
      # for installed-package compatibility.
      legacy_data_mask <- grepl(
        "Expressions to apply to each group.",
        description,
        fixed = TRUE
      )
      legacy_tidy_select <- grepl(
        "Defused R code describing a selection",
        description,
        fixed = TRUE
      ) || grepl("Selection inputs. See the help for selection helpers.",
                 description, fixed = TRUE)

      mode <- if (grepl("data-masking", description, fixed = TRUE) ||
                  legacy_data_mask) {
        "data_mask"
      } else if (grepl("tidy-select", description, fixed = TRUE)) {
        "tidy_select"
      } else if (legacy_tidy_select) {
        "tidy_select"
      } else {
        next
      }

      documented <- strsplit(rd_text(item[[1L]]), ",", fixed = TRUE)[[1L]]
      documented <- trimws(documented)
      documented <- documented[nzchar(documented)]
      for (name in documented) {
        modes[[name]] <- mode
      }
    }
  }
  modes
}

exported_aliases <- function(rd, exports) {
  aliases <- vapply(rd_sections(rd, "\\alias"), rd_text, character(1L))
  intersect(aliases, exports)
}

function_formals <- function(package, name) {
  object <- tryCatch(
    getExportedValue(package, name),
    error = function(...) NULL
  )
  if (!is.function(object)) {
    return(NULL)
  }
  names(formals(object))
}

derive_metadata <- function(package) {
  exports <- getNamespaceExports(package)
  metadata <- list()

  for (rd in tools::Rd_db(package)) {
    documented_modes <- argument_modes(rd)
    if (length(documented_modes) == 0L) {
      next
    }

    for (alias in exported_aliases(rd, exports)) {
      params <- function_formals(package, alias)
      if (is.null(params)) {
        next
      }
      matched <- documented_modes[intersect(names(documented_modes), params)]
      if (length(matched) == 0L) {
        next
      }

      if (is.null(metadata[[alias]])) {
        metadata[[alias]] <- list(params = params, eval = list())
      }
      for (name in names(matched)) {
        if (is.null(metadata[[alias]]$eval[[name]])) {
          metadata[[alias]]$eval[[name]] <- matched[[name]]
        }
      }
    }
  }
  metadata
}

merge_package <- function(package) {
  stub_dir <- file.path(repo_root, "stubs", package)
  stub_path <- file.path(stub_dir, paste0(package, ".json"))
  dir.create(stub_dir, recursive = TRUE, showWarnings = FALSE)

  if (file.exists(stub_path)) {
    stub <- jsonlite::read_json(stub_path, simplifyVector = FALSE)
  } else {
    stub <- list(
      schema_version = "1",
      package = package,
      version = "0.0.1",
      functions = list()
    )
  }

  derived <- derive_metadata(package)
  for (name in names(derived)) {
    generated <- derived[[name]]
    existing <- stub$functions[[name]]
    if (is.null(existing)) {
      existing <- list(
        params = as.list(generated$params),
        return = list(mode = "opaque", length = "unknown")
      )
    } else {
      existing_params <- unlist(existing$params, use.names = FALSE)
      missing_params <- setdiff(generated$params, existing_params)
      existing$params <- as.list(c(existing_params, missing_params))
    }

    existing_eval <- existing$eval
    if (is.null(existing_eval)) {
      existing_eval <- list()
    }
    for (parameter in names(generated$eval)) {
      if (is.null(existing_eval[[parameter]])) {
        existing_eval[[parameter]] <- generated$eval[[parameter]]
      }
    }
    if (length(existing_eval) > 0L) {
      existing$eval <- existing_eval
    }
    stub$functions[[name]] <- existing
  }

  stub$functions <- stub$functions[sort(names(stub$functions))]
  jsonlite::write_json(
    stub,
    stub_path,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = "null"
  )
  cat(sprintf("%s: wrote %d function entries to %s\n",
              package, length(stub$functions), stub_path))
}

for (package in args) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop(sprintf("package '%s' is not installed", package), call. = FALSE)
  }
  merge_package(package)
}
