#!/usr/bin/env Rscript

# Calling arbitrary base functions is unsafe: q(), system(), unlink(), and
# similar functions can terminate the audit or mutate the host. This audit is
# therefore gated to a complete reviewed inventory of side-effect-free
# primitives. Each entry pins both its zero-argument runtime contract and the
# stub formal sequence; changing either requires deliberate review here.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else "."
root <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("audit_zero_arg_primitives.R requires jsonlite")
}

# Each entry pins `first_formal_required`, the stub's first-formal required
# flag, independently of the zero-argument runtime contract: R accepts the
# degenerate zero-argument calls of as.character/as.integer/as.numeric/rep,
# but this repository keeps their `x` formals required (the master lineage's
# exact-argument-checking form; upstream d445345 dropped the flags instead).
# Changing any pinned value requires deliberate review here.
reviewed <- list(
  "as.character" = list(params = c("x", "..."), succeeds = TRUE, type = "character", length = 0L, first_formal_required = TRUE),
  "as.double" = list(params = "x", succeeds = TRUE, type = "double", length = 0L, first_formal_required = FALSE),
  "as.integer" = list(params = c("x", "..."), succeeds = TRUE, type = "integer", length = 0L, first_formal_required = TRUE),
  "as.logical" = list(params = "x", succeeds = TRUE, type = "logical", length = 0L, first_formal_required = FALSE),
  "as.numeric" = list(params = c("x", "..."), succeeds = TRUE, type = "double", length = 0L, first_formal_required = TRUE),
  "as.raw" = list(params = "x", succeeds = FALSE, first_formal_required = TRUE),
  "c" = list(params = "...", succeeds = TRUE, type = "NULL", length = 0L, first_formal_required = FALSE),
  "expression" = list(params = "...", succeeds = TRUE, type = "expression", length = 0L, first_formal_required = FALSE),
  "list" = list(params = "...", succeeds = TRUE, type = "list", length = 0L, first_formal_required = FALSE),
  "rep" = list(params = c("x", "..."), succeeds = TRUE, type = "NULL", length = 0L, first_formal_required = TRUE)
)
if (!length(reviewed)) stop("reviewed zero-argument primitive inventory is empty")

stub <- jsonlite::fromJSON(
  file.path(root, "stubs", "base", "base.json"),
  simplifyVector = FALSE
)
param_names <- function(signature) {
  vapply(signature$params, function(param) if (is.character(param)) param else param$name, character(1))
}
first_required <- function(signature) {
  length(signature$params) > 0L &&
    is.list(signature$params[[1L]]) &&
    isTRUE(signature$params[[1L]]$required)
}

invoked <- 0L
for (name in names(reviewed)) {
  contract <- reviewed[[name]]
  signature <- stub$functions[[name]]
  if (is.null(signature)) stop(sprintf("Reviewed primitive base::%s is missing from the stub", name))
  if (!identical(param_names(signature), contract$params)) {
    stop(sprintf("base::%s stub parameters differ from the reviewed sequence", name))
  }

  fn <- get(name, envir = baseenv(), inherits = FALSE)
  if (!is.primitive(fn)) stop(sprintf("Reviewed base::%s is no longer a primitive", name))
  invoked <- invoked + 1L
  result <- tryCatch(
    list(succeeded = TRUE, value = do.call(fn, list())),
    error = function(cnd) list(succeeded = FALSE, error = conditionMessage(cnd))
  )
  if (!identical(result$succeeded, contract$succeeds)) {
    stop(sprintf("base::%s zero-argument behavior changed", name))
  }
  if (isTRUE(contract$succeeds)) {
    if (!identical(typeof(result$value), contract$type) || !identical(length(result$value), contract$length)) {
      stop(sprintf("base::%s zero-argument result changed", name))
    }
  }
  if (!identical(first_required(signature), isTRUE(contract$first_formal_required))) {
    stop(sprintf("base::%s stub first-formal required flag differs from the reviewed contract", name))
  }
}
if (!identical(invoked, length(reviewed))) stop("not every reviewed primitive was invoked")
cat(sprintf("Verified %d reviewed zero-argument primitive contracts.\n", invoked))
