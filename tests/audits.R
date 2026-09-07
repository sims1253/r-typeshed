#!/usr/bin/env Rscript
# Exercise the audit's exit status with isolated valid and invalid declarations.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
source(file.path(root, "scripts", "param_optionality.R"))

# Inner closures have their own arguments and missingness. Their bodies and
# defaults cannot make an enclosing function's required arguments optional.
for (fn in list(
  function(x) { inner <- function(x) missing(x); x },
  function(x) { inner <- function() nargs(); x },
  function(x) { inner <- function(x, y = missing(x)) y; x }
)) stopifnot(!length(missing_optional_params(fn)))
stopifnot(identical(missing_optional_params(function(x) {
  inner <- function(y) missing(y)
  if (missing(x)) return(NULL)
  x
}), "x"))
stopifnot(identical(missing_optional_params(function(x) {
  if (nargs() == 0L) return(NULL)
  x
}), "x"))

fixture <- tempfile("typeshed-audit-")
dir.create(file.path(fixture, "scripts"), recursive = TRUE)
dir.create(file.path(fixture, "stubs", "base"), recursive = TRUE)
for (script in c("audit_typeshed.R", "param_optionality.R")) {
  stopifnot(file.copy(file.path(root, "scripts", script), file.path(fixture, "scripts", script)))
}
run <- function(functions, status) {
  jsonlite::write_json(list(functions = functions), file.path(fixture, "stubs", "base", "base.json"), auto_unbox = TRUE)
  output <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(file.path(fixture, "scripts", "audit_typeshed.R")), "--base-formals-only"),
    stdout = TRUE, stderr = TRUE))
  actual <- attr(output, "status")
  if (is.null(actual)) actual <- 0L
  stopifnot(actual == status)
  invisible(output)
}
valid <- run(list(head = list(params = list("x", "n"))), 0L)
stopifnot(any(grepl("Reviewed forwarded formals (1)", valid, fixed = TRUE)))
invalid <- run(list(fft = list(params = list("x", "inverse"))), 1L)
stopifnot(any(grepl("fft::x", invalid, fixed = TRUE)))
run(list(head = list(params = list("x", "invented"))), 1L)
run(list(numeric = list(params = list(list(name = "length", required = TRUE)))), 1L)
# An opaque environment makes no non-NA claim and must not trigger anyNA().
jsonlite::write_json(list(package = "base", functions = list(identity = list(params = list("x"))),
  datasets = list(.GlobalEnv = list(mode = "opaque", length = "unknown", na = TRUE))),
  file.path(fixture, "stubs", "base", "base.json"), auto_unbox = TRUE)
# Unlike .GlobalEnv, classed environments dispatch through is.na() and warn.
if (requireNamespace("ggplot2", quietly = TRUE)) {
  dir.create(file.path(fixture, "stubs", "ggplot2"))
  jsonlite::write_json(list(package = "ggplot2", functions = list(),
    datasets = list(Geom = list(mode = "opaque", length = "unknown", na = TRUE))),
    file.path(fixture, "stubs", "ggplot2", "ggplot2.json"), auto_unbox = TRUE)
}
output <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
  c("--vanilla", shQuote(file.path(fixture, "scripts", "audit_typeshed.R"))),
  stdout = TRUE, stderr = TRUE))
stopifnot(is.null(attr(output, "status")), !any(grepl("Warning", output, fixed = TRUE)))
unlink(fixture, recursive = TRUE)
cat("Audit failures and reviewed forwarding verified.\n")

# Capture metadata needs complete formals even for normally evaluated controls.
base_doc <- jsonlite::read_json(file.path(root, "stubs", "base", "base.json"))
for (name in c("delayedAssign", "substitute")) {
  stub <- base_doc$functions[[name]]
  live <- formals(args(get(name, baseenv())))
  stopifnot(identical(unlist(stub$params, use.names = FALSE), names(live)))
  stopifnot(all(vapply(stub$params, is.character, logical(1))))
}
stopifnot(identical(base_doc$functions$delayedAssign$eval, list(value = "captures_promise")))
stopifnot(identical(base_doc$functions$substitute$eval, list(expr = "captures_promise")))
live <- formals(args(base::delayedAssign))
stopifnot(identical(live$eval.env, quote(parent.frame(1))))
stopifnot(identical(live$assign.env, quote(parent.frame(1))))
local({
  x <- 7L
  delayedAssign("held", x)
  stopifnot(identical(held, 7L), identical(substitute(x), 7L))
})
stopifnot(identical(substitute(en = list(x = 2L), ex = x), 2L))
stopifnot(inherits(tryCatch(substitute(e = x), error = identity), "error"))
cat("Base capture formals and environment defaults verified.\n")
