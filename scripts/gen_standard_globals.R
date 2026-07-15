#!/usr/bin/env Rscript

# Keep the base stub's standard globals and base/recommended datasets in sync
# with the R installation running this script. Curated dataset entries win over
# generated entries, so running this script never discards hand-written types.

standard_packages <- c("base", "methods", "datasets", "utils", "grDevices", "graphics", "stats")

dataset_length <- function(value) {
  known <- c(
    0L:9L, 11L, 12L, 15L, 19L:21L, 24L, 26L, 30L:32L, 35L, 39L, 43L,
    47L:50L, 54L, 60L, 64L, 66L, 70L:72L, 84L, 88L, 98L, 100L, 132L,
    141L, 150L, 153L, 176L, 240L, 248L, 272L, 289L, 468L, 578L, 1000L,
    2820L
  )
  length <- length(value)
  if (length %in% known) as.character(length) else "unknown"
}

dataset_type <- function(value) {
  classes <- class(value)
  mode <- switch(typeof(value),
    character = "character", complex = "complex", double = "double",
    integer = "integer", list = "list", logical = "logical", raw = "raw",
    "opaque"
  )
  result <- list(mode = mode, length = dataset_length(value), na = anyNA(value))
  if (!identical(classes, implicit_class(value))) result$class <- as.list(unname(classes))
  if (is.data.frame(value)) {
    result$columns <- lapply(value, dataset_type)
  }
  result
}

implicit_class <- function(value) {
  switch(typeof(value),
    character = "character", complex = "complex", double = "numeric",
    integer = "integer", list = "list", logical = "logical", raw = "raw",
    class(value)
  )
}

generated_datasets <- function() {
  inventory <- data(package = standard_packages)$results
  if (is.null(inventory) || nrow(inventory) == 0L) return(list())
  env <- new.env(parent = emptyenv())
  for (i in seq_len(nrow(inventory))) {
    item <- inventory[i, "Item"]
    load_name <- if (grepl(" \\([^)]*\\)$", item)) sub("^.* \\(([^)]*)\\)$", "\\1", item) else item
    suppressWarnings(try(data(list = load_name, package = inventory[i, "Package"], envir = env), silent = TRUE))
  }
  names <- sort(unique(sub(" .*$", "", inventory[, "Item"])), method = "radix")
  names <- names[vapply(names, exists, logical(1), envir = env, inherits = FALSE)]
  setNames(lapply(names, function(name) dataset_type(get(name, envir = env, inherits = FALSE))), names)
}

generated_globals <- function(document) {
  expression <- paste(
    "packages <- c(\"package:base\", \"package:methods\", \"package:datasets\",",
    "  \"package:utils\", \"package:grDevices\", \"package:graphics\", \"package:stats\")",
    "symbols <- sort(unique(unlist(lapply(packages, function(package) ls(as.environment(package), all.names = TRUE)))))",
    "for (symbol in symbols) {",
    "  value <- get(symbol, inherits = TRUE)",
    "  cat(if (is.function(value)) \"F\" else \"V\", enc2utf8(symbol), sep = \"\\t\")",
    "  cat(\"\\n\")",
    "}", sep = "\n"
  )
  output <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", "-e", shQuote(expression)), stdout = TRUE)
  kinds <- substr(output, 1L, 1L)
  symbols <- substring(output, 3L)
  functions <- symbols[kinds == "F"]
  values <- symbols[kinds == "V"]
  typed_functions <- names(document$functions %||% list())
  typed_values <- names(document$datasets %||% list())
  existing <- unlist(document$globals$ambient %||% list(), use.names = FALSE)
  synthetic <- setdiff(existing, c(functions, values))
  list(
    ambient = sort(unique(c(synthetic, setdiff(values, typed_values))), method = "radix"),
    ambient_functions = sort(setdiff(functions, typed_functions), method = "radix")
  )
}

# Registered S3 methods need not be exported (for example stats registers
# print.anova). They still participate in UseMethod dispatch, so emit a
# conservative signature for every registration from the base/recommended
# namespaces. Curated entries already in the stub win, preserving their more
# precise return types.
generated_s3_methods <- function(document) {
  method_signature <- function(generic, class, method, ns) {
    value <- tryCatch(get(method, envir = ns, inherits = FALSE), error = function(e) NULL)
    if (is.null(value)) {
      value <- tryCatch(getS3method(generic, class, optional = TRUE, envir = ns), error = function(e) NULL)
    }
    params <- if (is.function(value)) names(formals(value)) else c("x", "...")
    if (is.null(params)) params <- character()
    list(
      generic = generic,
      class = class,
      params = as.list(unname(params)),
      "return" = list(mode = "opaque", length = "unknown", na = TRUE)
    )
  }

  entries <- list()
  for (package in standard_packages) {
    ns <- asNamespace(package)
    registered <- tryCatch(getNamespaceInfo(package, "S3methods"), error = function(e) NULL)
    # `base` has no namespace registry available through getNamespaceInfo.
    # Query each curated base generic instead; .S3methods exposes methods
    # registered but deliberately not exported, such as summary.connection.
    if ((is.null(registered) || !is.matrix(registered) || ncol(registered) < 3L) && package == "base") {
      generic_names <- unlist(document$globals$s3_generics %||% list(), use.names = FALSE)
      base_entries <- unlist(lapply(generic_names, function(generic) {
        methods <- tryCatch(utils:::.S3methods(generic), error = function(e) character())
        methods <- sub("[*]$", "", methods)
        methods[startsWith(methods, paste0(generic, "."))]
      }), use.names = FALSE)
      generic <- vapply(base_entries, function(method) {
        matches <- generic_names[startsWith(method, paste0(generic_names, "."))]
        matches[[which.max(nchar(matches))]]
      }, character(1))
      registered <- cbind(generic, substring(base_entries, nchar(generic) + 2L), base_entries)
    }
    if (is.null(registered) || !is.matrix(registered) || ncol(registered) < 3L) next
    for (i in seq_len(nrow(registered))) {
      generic <- registered[i, 1L]
      class <- registered[i, 2L]
      method <- registered[i, 3L]
      if (!nzchar(generic) || !nzchar(class) || !nzchar(method)) next
      key <- paste(generic, class, sep = "\r")
      entries[[key]] <- method_signature(generic, class, method, ns)
    }
  }
  entries[sort(names(entries), method = "radix")]
}

`%||%` <- function(left, right) if (is.null(left)) right else left

main <- function(argv) {
  check <- "--check" %in% argv
  argv <- argv[argv != "--check"]
  if (length(argv) > 1L || any(argv %in% c("--help", "-h"))) {
    cat("Usage: Rscript --vanilla scripts/gen_standard_globals.R [stub] [--check]\n")
    return(if (length(argv) > 1L) 2L else 0L)
  }
  script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  script <- if (length(script_arg)) sub("^--file=", "", script_arg[[1]]) else "scripts/gen_standard_globals.R"
  stub <- if (length(argv)) argv[[1]] else file.path(dirname(dirname(normalizePath(script))), "stubs", "base", "base.json")
  document <- jsonlite::fromJSON(stub, simplifyVector = FALSE)

  generated <- generated_datasets()
  existing_datasets <- document$datasets %||% list()
  document$datasets <- c(existing_datasets, generated[setdiff(names(generated), names(existing_datasets))])
  existing_s3_methods <- unname(document$s3_methods %||% list())
  existing_s3_keys <- vapply(existing_s3_methods, function(entry) paste(entry$generic, entry$class, sep = "\r"), character(1))
  generated_methods <- generated_s3_methods(document)
  document$s3_methods <- c(existing_s3_methods, unname(generated_methods[setdiff(names(generated_methods), existing_s3_keys)]))
  expected <- generated_globals(document)

  stale <- !identical(document$globals$ambient %||% list(), as.list(expected$ambient)) ||
    !identical(document$globals$ambient_functions %||% list(), as.list(expected$ambient_functions)) ||
    !identical(existing_datasets, document$datasets) ||
    !identical(existing_s3_methods, document$s3_methods)
  if (check) {
    if (stale) {
      message(sprintf("%s: standard globals or datasets are stale", stub))
      return(1L)
    }
    return(0L)
  }

  document$globals$ambient <- as.list(expected$ambient)
  document$globals$ambient_functions <- as.list(expected$ambient_functions)
  writeLines(jsonlite::toJSON(document, auto_unbox = TRUE, pretty = TRUE, null = "null"), stub, useBytes = TRUE)
  0L
}

quit(status = main(commandArgs(trailingOnly = TRUE)))
