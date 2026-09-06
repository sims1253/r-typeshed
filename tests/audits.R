#!/usr/bin/env Rscript
# Exercise the audit's exit status with isolated valid and invalid declarations.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
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
unlink(fixture, recursive = TRUE)
cat("Audit failures and reviewed forwarding verified.\n")
