#!/usr/bin/env Rscript

# Exercise the command-line generators in a disposable checkout.
script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
stopifnot(requireNamespace("jsonlite", quietly = TRUE), requireNamespace("dplyr", quietly = TRUE))

main <- function() {
  work <- tempfile("r-typeshed-generators-")
  dir.create(file.path(work, "scripts"), recursive = TRUE)
  on.exit(unlink(work, recursive = TRUE))
  file.copy(list.files(file.path(root, "scripts"), full.names = TRUE), file.path(work, "scripts"))
  run <- function(script, package, output) {
    status <- system2(file.path(R.home("bin"), "Rscript"),
                      c("--vanilla", shQuote(file.path(work, "scripts", script)), package),
                      stdout = output)
    stopifnot(status == 0L)
  }
  output <- file.path(work, "draft.json")
  run("gen_typeshed.R", "dplyr", output)
  draft <- jsonlite::read_json(output)
  exports <- getNamespaceExports("dplyr")
  functions <- exports[vapply(exports, function(name) is.function(getExportedValue("dplyr", name)), logical(1))]
  stopifnot(identical(draft$schema_version, "2"), setequal(names(draft$functions), functions))
  stopifnot(all(vapply(draft$functions, function(sig) isTRUE(sig$return$na), logical(1))))

  stopifnot(identical(draft$functions$mutate$params[[1]], list(name = ".data", required = TRUE)))
  stopifnot(identical(draft$functions$mutate$params[[2]], "..."))

  dir.create(file.path(work, "stubs", "dplyr"), recursive = TRUE)
  path <- file.path(work, "stubs", "dplyr", "dplyr.json")
  data_param <- list(name = ".data", required = TRUE, type = list(mode = "list", length = "unknown"))
  result <- list(mode = "list", length = "arg0")
  stub <- list(schema_version = "2", package = "dplyr", version = "test", functions = list(
    mutate = list(params = list(data_param, "..."), "return" = result, eval = list(.data = "normal"))
  ))
  jsonlite::write_json(stub, path, auto_unbox = TRUE)
  run("gen_nse_metadata.R", "dplyr", output)
  generated <- jsonlite::read_json(path)
  mutate <- generated$functions$mutate
  names <- vapply(mutate$params, function(param) if (is.character(param)) param else param$name, character(1))
  stopifnot(identical(mutate$params[[1]], data_param), identical(mutate$return, result))
  stopifnot(identical(names, names(formals(dplyr::mutate))))
  stopifnot(identical(mutate$eval$.data, "normal"), identical(mutate$eval[["..."]], "data_mask"))
  run("gen_nse_metadata.R", "dplyr", output)
  stopifnot(identical(jsonlite::read_json(path), generated))
  # Upstream formal order must not change curated positional metadata.
  generated$functions$mutate$params <- list("...", data_param)
  generated$functions$mutate$higher_order <- list(callback_param = ".data", callback_position = 1L)
  jsonlite::write_json(generated, path, auto_unbox = TRUE)
  run("gen_nse_metadata.R", "dplyr", output)
  reordered <- jsonlite::read_json(path)
  stopifnot(identical(reordered$functions$mutate$params[1:2], list("...", data_param)))
  stopifnot(identical(reordered$functions$mutate$higher_order, generated$functions$mutate$higher_order))
  stopifnot(identical(reordered$functions$mutate$return, result))
  expected <- c("...", ".data", setdiff(names(formals(dplyr::mutate)), c("...", ".data")))
  actual <- vapply(reordered$functions$mutate$params, function(param) if (is.character(param)) param else param$name, character(1))
  stopifnot(identical(actual, expected))
  generated <- reordered
  run("gen_nse_metadata.R", "dplyr", output)
  stopifnot(identical(jsonlite::read_json(path), generated))
  # Existing paths need not match package capitalization (for example Rcpp).
  alternate <- file.path(work, "stubs", "DPLYR", "dplyr.json")
  dir.create(dirname(alternate))
  stopifnot(file.rename(path, alternate))
  run("gen_nse_metadata.R", "dplyr", output)
  stopifnot(!file.exists(path), identical(jsonlite::read_json(alternate), generated))

  # Ambiguous paths must fail before changing either curated file.
  stopifnot(file.copy(alternate, path))
  before <- lapply(c(path, alternate), readLines)
  status <- system2(file.path(R.home("bin"), "Rscript"),
                    c("--vanilla", shQuote(file.path(work, "scripts", "gen_nse_metadata.R")), "dplyr"),
                    stdout = output, stderr = output)
  stopifnot(status != 0L, any(grepl("Multiple stubs for dplyr", readLines(output), fixed = TRUE)))
  stopifnot(identical(lapply(c(path, alternate), readLines), before))
  unlink(c(path, alternate))
  run("gen_nse_metadata.R", "dplyr", output)
  fresh <- jsonlite::read_json(path)
  stopifnot(identical(fresh$schema_version, "2"))
  stopifnot(all(vapply(fresh$functions, function(sig) isTRUE(sig$return$na), logical(1))))
  cat("Generator drafts, re-exports, curated parameters, and idempotence verified.\n")
}

main()
