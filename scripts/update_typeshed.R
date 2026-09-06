#!/usr/bin/env Rscript

valid_package <- function(package) {
  length(package) == 1L && !is.na(package) && grepl("^[A-Za-z][A-Za-z0-9.]*$", package) && !endsWith(package, ".")
}

upstream_versions <- function(packages) {
  index_for <- function(repository) tryCatch(
    available.packages(repos = repository, type = "source"),
    error = function(error) { warning(conditionMessage(error)); NULL }
  )
  cran <- index_for("https://cloud.r-project.org")
  stan <- if ("cmdstanr" %in% packages) index_for("https://stan-dev.r-universe.dev") else NULL
  versions <- lapply(packages, function(package) {
    if (package == "base") return(as.character(getRversion()))
    index <- if (package == "cmdstanr") stan else cran
    if (!(package %in% rownames(index))) {
      warning(sprintf("Skipping %s: unavailable in its upstream repository", package))
      return(NULL)
    }
    unname(index[package, "Version"])
  })
  setNames(versions, packages)[!vapply(versions, is.null, logical(1))]
}

changed_packages <- function(previous, current) {
  names(current)[!vapply(names(current), function(package) identical(previous[[package]], current[[package]]), logical(1))]
}

merge_draft <- function(curated, draft) {
  added <- setdiff(names(draft$functions), names(curated$functions))
  if (!length(added)) return(curated)
  curated$functions <- c(curated$functions, draft$functions[added])
  curated$functions <- curated$functions[sort(names(curated$functions), method = "radix")]
  curated
}

parameter_names <- function(signature) {
  vapply(signature$params, function(param) if (is.character(param)) param else param$name, character(1))
}

signature_changes <- function(curated, draft) {
  shared <- intersect(names(curated$functions), names(draft$functions))
  shared[!vapply(shared, function(name) {
    old <- curated$functions[[name]]
    new <- draft$functions[[name]]
    if (!identical(parameter_names(old), parameter_names(new))) return(FALSE)
    all(vapply(seq_along(old$params), function(i) {
      param <- old$params[[i]]
      if (is.character(param) || is.null(param$required)) return(TRUE)
      actual <- new$params[[i]]
      required <- is.list(actual) && isTRUE(actual$required)
      identical(param$required, required)
    }, logical(1)))
  }, logical(1))]
}

bump_version <- function(version) {
  if (!grepl("^[0-9]+[.][0-9]+[.][0-9]+$", version)) return(version)
  parts <- as.integer(strsplit(version, ".", fixed = TRUE)[[1]])
  parts[[3]] <- parts[[3]] + 1L
  paste(parts, collapse = ".")
}

write_json <- function(value, path) {
  writeLines(jsonlite::toJSON(value, pretty = TRUE, auto_unbox = TRUE, null = "null"), path, useBytes = TRUE)
}

stub_path <- function(package, root) {
  paths <- list.files(file.path(root, "stubs"), pattern = "[.]json$", recursive = TRUE, full.names = TRUE)
  matches <- paths[basename(paths) == paste0(package, ".json")]
  if (length(matches) > 1L) stop(sprintf("Multiple stubs for %s", package))
  if (length(matches)) matches[[1]] else file.path(root, "stubs", package, paste0(package, ".json"))
}

prepare_package <- function(package, root, report, expected_version = NULL) {
  if (!requireNamespace(package, quietly = TRUE)) stop(sprintf("%s is not installed", package))
  version <- as.character(packageVersion(package))
  if (!is.null(expected_version) && !identical(version, expected_version)) stop(sprintf("Expected %s %s, installed %s", package, expected_version, version))
  stub_path <- stub_path(package, root)
  previous <- if (file.exists(stub_path)) jsonlite::read_json(stub_path) else NULL
  lines <- c(sprintf("Prepare typeshed for `%s` %s.", package, version), "", "This is a generated draft. Review return types, evaluation modes, and semantic metadata before merging.", "")
  run <- function(script, args = character(), output = "") {
    status <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", shQuote(script), shQuote(args)), stdout = output)
    if (status != 0L) stop(sprintf("%s failed (%d)", basename(script), status))
  }
  if (package == "base") {
    original_text <- readLines(stub_path, warn = FALSE)
    run(file.path(root, "scripts", "gen_standard_globals.R"), stub_path)
    updated <- jsonlite::read_json(stub_path)
    if (identical(updated, previous)) {
      writeLines(original_text, stub_path, useBytes = TRUE)
    } else {
      updated$version <- bump_version(previous$version)
      write_json(updated, stub_path)
    }
    lines <- c(lines, "Refreshed the generated base inventory; existing types are preserved.")
  } else {
    # Generate in a disposable tree so NSE derivation cannot reorder curated
    # parameters or invalidate position-based semantic metadata.
    work <- tempfile("typeshed-draft-")
    on.exit(unlink(work, recursive = TRUE), add = TRUE)
    dir.create(file.path(work, "scripts"), recursive = TRUE)
    file.copy(list.files(file.path(root, "scripts"), full.names = TRUE), file.path(work, "scripts"))
    draft_path <- file.path(work, "stubs", package, paste0(package, ".json"))
    dir.create(dirname(draft_path), recursive = TRUE)
    run(file.path(work, "scripts", "gen_typeshed.R"), package, draft_path)
    run(file.path(work, "scripts", "gen_nse_metadata.R"), package)
    draft <- jsonlite::read_json(draft_path)
    if (!length(draft$functions)) stop("No exported functions found; value-only packages need manual curation")
    if (is.null(previous)) {
      draft$version <- "0.0.1"
      updated <- draft
      lines <- c(lines, sprintf("Added %d draft functions. Unknown returns are deliberately opaque and may contain NA.", length(draft$functions)))
    } else {
      added <- setdiff(names(draft$functions), names(previous$functions))
      changed <- signature_changes(previous, draft)
      removed <- setdiff(names(previous$functions), names(draft$functions))
      updated <- merge_draft(previous, draft)
      lines <- c(lines, sprintf("Added %d missing exported functions. Existing entries and metadata are preserved.", length(added)), "", "Signatures requiring review (not overwritten):")
      for (name in changed) lines <- c(lines, sprintf("- `%s`: (%s) → (%s); review required/default flags too", name, paste(parameter_names(previous$functions[[name]]), collapse = ", "), paste(parameter_names(draft$functions[[name]]), collapse = ", ")))
      if (!length(changed)) lines <- c(lines, "- No formal-name or declared-requiredness changes detected.")
      if (length(removed)) lines <- c(lines, "", "Curated entries absent from the exported-function inventory (retained):", paste0("- `", removed, "`"))
    }
    # A package release without a stub change should not reformat the file.
    if (is.null(previous) || !identical(updated$functions, previous$functions)) {
      if (!is.null(previous)) updated$version <- bump_version(previous$version)
      dir.create(dirname(stub_path), recursive = TRUE, showWarnings = FALSE)
      write_json(updated, stub_path)
    }
  }
  versions_path <- file.path(root, "upstream-versions.json")
  versions <- if (file.exists(versions_path)) jsonlite::read_json(versions_path) else list()
  versions[[package]] <- version
  write_json(versions[sort(names(versions), method = "radix")], versions_path)
  lines <- c(lines, "", "Before merging:", "- Review the signature changes above and curate new entries.", "- Review the schema validation and R audit results below.", "- Approve any waiting CI workflows on this draft PR, then mark it ready for review.")
  writeLines(lines, report, useBytes = TRUE)
}

main <- function(args) {
  if (!length(args) || !(args[[1]] %in% c("plan", "prepare"))) stop("Usage: update_typeshed.R plan [package] | prepare <package> <version> <report.md>")
  script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
  root <- dirname(dirname(normalizePath(script)))
  if (!requireNamespace("jsonlite", quietly = TRUE)) stop("jsonlite is required")
  package <- if (length(args) >= 2L) args[[2]] else ""
  if (nzchar(package) && !valid_package(package)) stop("Invalid R package name")
  if (args[[1]] == "prepare") {
    if (!nzchar(package) || length(args) != 4L) stop("prepare requires a package, version, and report path")
    prepare_package(package, root, args[[4]], args[[3]])
  } else {
    previous <- jsonlite::read_json(file.path(root, "upstream-versions.json"))
    packages <- if (nzchar(package)) package else names(previous)
    current <- upstream_versions(packages)
    if (nzchar(package) && is.null(current[[package]])) stop("Requested package is unavailable")
    selected <- if (nzchar(package)) package else changed_packages(previous, current)
    matrix <- lapply(selected, function(package) list(package = package, version = current[[package]], stub = substring(stub_path(package, root), nchar(root) + 2L)))
    cat(jsonlite::toJSON(unname(matrix), auto_unbox = TRUE), "\n")
  }
}

if (sys.nframe() == 0L) main(commandArgs(trailingOnly = TRUE))
