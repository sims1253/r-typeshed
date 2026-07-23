#!/usr/bin/env Rscript

# Audit provenance for the schema-2 function-semantics declarations.  Keep
# this separate from the namespace/name audit: these facts come from R's
# actual formals and rlang's installed implementation, not from JSON shape.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else "."
root <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("audit_function_semantics.R requires jsonlite")

base <- jsonlite::fromJSON(file.path(root, "stubs", "base", "base.json"), simplifyVector = FALSE)
rlang_stub <- jsonlite::fromJSON(file.path(root, "stubs", "rlang", "rlang.json"), simplifyVector = FALSE)
param_names <- function(sig) vapply(sig$params, function(param) if (is.character(param)) param else param$name, character(1))
expect <- function(ok, message) if (!isTRUE(ok)) stop(message, call. = FALSE)

# These are real public formals, including the controls that must not be
# mistaken for recycled paste values.
for (name in c("paste", "paste0", "source", "intersect")) {
  actual <- names(formals(get(name, envir = baseenv())))
  declared <- param_names(base$functions[[name]])
  expect(identical(declared, actual), sprintf("base::%s parameters differ from installed R", name))
}
expect(identical(base$functions$intersect$return_length$kind, "shortest_of"), "intersect must use shortest_of")
for (name in c("paste", "paste0")) {
  rule <- base$functions[[name]]$return_length
  expect(identical(rule$kind, "recycled_values"), sprintf("%s must use recycled_values", name))
  expect(identical(rule$collapse$param, "collapse") && identical(rule$recycle0$param, "recycle0"), sprintf("%s control provenance is incomplete", name))
}
source_rule <- base$functions$source$conditional_scope_effect
expect(identical(source_rule$current_scope_when$param, "local"), "source conditional scope must be controlled by local")

if (!requireNamespace("rlang", quietly = TRUE)) {
  cat("SKIP: rlang is not installed; base function-semantics provenance verified.\n")
  quit(status = 0)
}
ns <- asNamespace("rlang")
is_null_formals <- formals(get("is_null", ns))
expect(is.primitive(get("is_null", ns)) || identical(names(is_null_formals), "x"), "rlang::is_null must take x")
checks <- names(Filter(function(sig) !is.null(sig$assertion), rlang_stub$functions))
for (name in checks) {
  expect(exists(name, ns, inherits = FALSE), sprintf("rlang::%s does not exist", name))
  actual <- names(formals(get(name, ns)))
  assertion <- rlang_stub$functions[[name]]$assertion
  expect(all(c("arg", "call") %in% actual), sprintf("rlang::%s lacks standalone arg/call provenance", name))
  expect(identical(assertion$provenance$kind, "standalone_types_check"), sprintf("rlang::%s has unsupported assertion provenance", name))
  expect(identical(sort(unlist(assertion$provenance$fingerprint_params)), c("arg", "call")), sprintf("rlang::%s has wrong assertion fingerprint", name))
}
cat(sprintf("Function-semantics provenance verified (%d standalone rlang checks).\n", length(checks)))
