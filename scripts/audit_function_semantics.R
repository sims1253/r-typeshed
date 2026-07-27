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
as_strings <- function(value) unlist(value, recursive = FALSE, use.names = FALSE)
expect <- function(ok, message) if (!isTRUE(ok)) stop(message, call. = FALSE)

# These are real public formals, including controls that must not be mistaken
# for recycled paste values. Semantic parameter names are formal names and are
# interpreted only after ordinary R argument binding.
for (name in c("paste", "paste0", "source", "intersect")) {
  actual <- names(formals(get(name, envir = baseenv())))
  declared <- param_names(base$functions[[name]])
  expect(identical(declared, actual), sprintf("base::%s parameters differ from installed R", name))
}
intersect_sig <- base$functions$intersect
intersect_rule <- intersect_sig$return_length
expect(identical(intersect_sig$return, "arg0"), "intersect must preserve its first argument's element type")
expect(identical(intersect_rule$kind, "zero_if_any_param_zero"), "intersect must preserve only its exact-zero fact")
expect(identical(as_strings(intersect_rule$params), c("x", "y")), "intersect exact-zero parameters are incomplete")
for (name in c("paste", "paste0")) {
  rule <- base$functions[[name]]$return_length
  declared <- param_names(base$functions[[name]])
  expect(identical(rule$kind, "recycled_values"), sprintf("%s must use recycled_values", name))
  values <- as_strings(rule$value_params)
  controls <- as_strings(rule$control_params)
  expect(identical(values, "..."), sprintf("%s values must come from dots", name))
  expect(!length(intersect(values, controls)), sprintf("%s values and controls overlap", name))
  expect(identical(controls, setdiff(declared, "...")), sprintf("%s controls do not cover every non-value formal", name))
  expect(identical(rule$collapse$param, "collapse") && identical(rule$collapse$when, "non_null") && identical(rule$collapse$length, "1"), sprintf("%s collapse provenance is incomplete", name))
  expect(identical(rule$recycle0$param, "recycle0") && identical(rule$recycle0$when, "true") && identical(rule$recycle0$any_value_zero, "zero"), sprintf("%s recycle0 provenance is incomplete", name))
}
source_sig <- base$functions$source
source_file_param <- source_sig$params[[match("file", param_names(source_sig))]]
expect(identical(source_file_param$default, TRUE), "source file must preserve its missing-argument default")
source_rule <- source_sig$conditional_scope_effect
expect(identical(source_rule$effect, "unknown_bindings"), "source must have an unknown-bindings scope effect")
expect(identical(source_rule$current_scope_when$param, "local") && identical(source_rule$current_scope_when$equals, TRUE), "source conditional scope must be controlled by local = TRUE")
expect(identical(source_rule$default_current_scope, "top_level"), "source default scope must be top-level only")

# Runtime witnesses for the exact outcomes recorded above. In particular,
# intersect's non-empty result is merely bounded, not exactly shortest.
expect(identical(intersect(integer(0), 1:3), integer(0)), "intersect empty input must be empty")
expect(length(intersect(1:3, 3:5)) == 1L, "intersect may be shorter than both non-empty inputs")
for (name in c("paste", "paste0")) {
  fn <- get(name, envir = baseenv())
  expect(identical(fn(character(0)), character(0)), sprintf("%s all-empty values must be empty", name))
  if (identical(name, "paste")) {
    expect(identical(fn(character(0), sep = ":"), character(0)), "paste sep must not become a value")
  }
  recycled <- if (identical(name, "paste")) " x" else "x"
  expect(identical(fn(character(0), "x"), recycled), sprintf("%s must recycle an empty value by default", name))
  expect(identical(fn(character(0), "x", recycle0 = TRUE), character(0)), sprintf("%s recycle0 must preserve emptiness", name))
  expect(identical(fn(character(0), collapse = ","), ""), sprintf("%s collapse must produce one string", name))
}
source_without_file <- new.env(parent = globalenv())
source(exprs = expression(.r_typeshed_source_exprs_binding <- TRUE), local = source_without_file)
expect(exists(".r_typeshed_source_exprs_binding", envir = source_without_file, inherits = FALSE), "source must accept exprs without file")
source_file <- tempfile("r-typeshed-source-", fileext = ".R")
source_binding <- ".r_typeshed_source_audit_binding"
writeLines(sprintf("assign(%s, TRUE)", deparse(source_binding)), source_file)
on.exit(unlink(source_file), add = TRUE)
if (exists(source_binding, envir = .GlobalEnv, inherits = FALSE)) rm(list = source_binding, envir = .GlobalEnv)
local_target <- new.env(parent = globalenv())
evalq(source(source_file, local = TRUE), local_target)
expect(exists(source_binding, envir = local_target, inherits = FALSE), "source(local = TRUE) must bind the caller environment")
expect(!exists(source_binding, envir = .GlobalEnv, inherits = FALSE), "source(local = TRUE) must not bind .GlobalEnv")
rm(list = source_binding, envir = local_target)
evalq(source(source_file), local_target)
expect(exists(source_binding, envir = .GlobalEnv, inherits = FALSE), "source() default must bind .GlobalEnv")
expect(!exists(source_binding, envir = local_target, inherits = FALSE), "source() default must not bind a non-global caller")
rm(list = source_binding, envir = .GlobalEnv)

if (!requireNamespace("rlang", quietly = TRUE)) {
  cat("SKIP: rlang is not installed; base function-semantics provenance verified.\n")
  quit(status = 0)
}
ns <- asNamespace("rlang")
is_null <- rlang_stub$functions$is_null
is_null_formals <- formals(get("is_null", ns))
expect(is.primitive(get("is_null", ns)) || identical(names(is_null_formals), "x"), "rlang::is_null must take x")
expect(identical(is_null$predicate$subject_param, "x"), "rlang::is_null predicate must bind x")
expect(identical(is_null$predicate$target$mode, "null") && identical(is_null$predicate$target$length, "0"), "rlang::is_null predicate target must be NULL")
checks <- names(Filter(function(sig) !is.null(sig$assertion), rlang_stub$functions))
assertion_witnesses <- list(
  check_bool = TRUE,
  check_string = "x",
  check_number_whole = 1L,
  check_number_decimal = 1.5,
  check_data_frame = data.frame(x = 1)
)
for (name in checks) {
  expect(exists(name, ns, inherits = FALSE), sprintf("rlang::%s does not exist", name))
  actual <- names(formals(get(name, ns)))
  declared <- param_names(rlang_stub$functions[[name]])
  assertion <- rlang_stub$functions[[name]]$assertion
  expect(identical(declared, actual), sprintf("rlang::%s parameters differ from installed R", name))
  expect(assertion$subject_param %in% actual, sprintf("rlang::%s subject is not a real formal", name))
  for (control in c(assertion$allow_null_param, assertion$allow_na_param)) if (!is.null(control)) {
    expect(control %in% actual, sprintf("rlang::%s control %s is not a real formal", name, control))
  }
  expect(identical(assertion$provenance$kind, "standalone_types_check"), sprintf("rlang::%s has unsupported assertion provenance", name))
  expect(identical(sort(unlist(assertion$provenance$fingerprint_params)), c("arg", "call")), sprintf("rlang::%s has wrong assertion fingerprint", name))
  expect(!inherits(try(do.call(get(name, ns), list(x = assertion_witnesses[[name]])), silent = TRUE), "try-error"), sprintf("rlang::%s rejects its declared target witness", name))
  if (!is.null(assertion$allow_null_param)) {
    expect(!inherits(try(do.call(get(name, ns), c(list(x = NULL), setNames(list(TRUE), assertion$allow_null_param))), silent = TRUE), "try-error"), sprintf("rlang::%s allow_null does not admit NULL", name))
  }
  if (!is.null(assertion$allow_na_param)) {
    expect(!inherits(try(do.call(get(name, ns), c(list(x = NA), setNames(list(TRUE), assertion$allow_na_param))), silent = TRUE), "try-error"), sprintf("rlang::%s allow_na does not admit NA", name))
  }
}
cat(sprintf("Function-semantics provenance verified (%d standalone rlang checks).\n", length(checks)))
