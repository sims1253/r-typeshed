#!/usr/bin/env Rscript

# Validate r-typeshed's data-level schema contracts.  ry's serde loader is the
# normative consumer validator; this companion gate makes semantic extensions
# reviewable before a ry release carries the corresponding loader.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else "."
root <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)

if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("validate_schema.R requires jsonlite")
}

fail <- function(path, message) stop(sprintf("%s: %s", path, message), call. = FALSE)
assert_names <- function(value, allowed, path) {
  extra <- setdiff(names(value), allowed)
  if (length(extra)) fail(path, sprintf("unrecognized field(s): %s", paste(extra, collapse = ", ")))
}
as_strings <- function(value) unlist(value, recursive = FALSE, use.names = FALSE)
assert_scalar_string <- function(value, path) {
  value <- as_strings(value)
  if (!is.character(value) || length(value) != 1L || !nzchar(value)) fail(path, "must be a non-empty string")
}
assert_param <- function(value, params, path) {
  assert_scalar_string(value, path)
  if (!(value %in% params)) fail(path, sprintf("references unknown parameter `%s`", value))
}
validate_rtype <- function(value, path) {
  if (!is.list(value)) fail(path, "must be an R type object")
  assert_names(value, c("mode", "length", "na", "note", "class", "columns", "members"), path)
  if (is.null(value$mode) || is.null(value$length)) fail(path, "requires mode and length")
  assert_scalar_string(value$mode, paste0(path, ".mode"))
  assert_scalar_string(value$length, paste0(path, ".length"))
}
validate_predicate <- function(value, params, path) {
  if (!is.list(value)) fail(path, "must be an object")
  assert_names(value, c("subject_param", "target"), path)
  if (is.null(value$subject_param) || is.null(value$target)) fail(path, "requires subject_param and target")
  assert_param(value$subject_param, params, paste0(path, ".subject_param"))
  validate_rtype(value$target, paste0(path, ".target"))
}
validate_assertion <- function(value, params, path) {
  if (!is.list(value)) fail(path, "must be an object")
  assert_names(value, c("subject_param", "target", "allow_null_param", "allow_na_param", "provenance"), path)
  if (is.null(value$subject_param) || is.null(value$target) || is.null(value$provenance)) {
    fail(path, "requires subject_param, target, and provenance")
  }
  assert_param(value$subject_param, params, paste0(path, ".subject_param"))
  validate_rtype(value$target, paste0(path, ".target"))
  for (field in c("allow_null_param", "allow_na_param")) if (!is.null(value[[field]])) assert_param(value[[field]], params, paste0(path, ".", field))
  provenance <- value$provenance
  if (!is.list(provenance)) fail(paste0(path, ".provenance"), "must be an object")
  assert_names(provenance, c("kind", "fingerprint_params"), paste0(path, ".provenance"))
  if (!identical(provenance$kind, "standalone_types_check")) fail(paste0(path, ".provenance.kind"), "must be standalone_types_check")
  fingerprint <- as_strings(provenance$fingerprint_params)
  if (!is.character(fingerprint) || !identical(sort(fingerprint), c("arg", "call"))) {
    fail(paste0(path, ".provenance.fingerprint_params"), "must be exactly arg and call")
  }
  for (param in fingerprint) assert_param(param, params, paste0(path, ".provenance.fingerprint_params"))
}
validate_return_length <- function(value, params, path) {
  if (!is.list(value)) fail(path, "must be an object")
  kind <- value$kind
  if (identical(kind, "zero_if_any_param_zero")) {
    assert_names(value, c("kind", "params"), path)
    zero_params <- as_strings(value$params)
    if (!is.character(zero_params) || length(zero_params) < 2L) fail(paste0(path, ".params"), "must name at least two parameters")
    if (anyDuplicated(zero_params)) fail(paste0(path, ".params"), "must not repeat parameters")
    for (param in zero_params) assert_param(param, params, paste0(path, ".params"))
  } else if (identical(kind, "recycled_values")) {
    assert_names(value, c("kind", "value_params", "control_params", "all_values_zero", "collapse", "recycle0"), path)
    if (!identical(value$all_values_zero, "zero")) fail(paste0(path, ".all_values_zero"), "must be zero")
    value_params <- as_strings(value$value_params)
    control_params <- as_strings(value$control_params)
    if (!is.character(value_params) || !length(value_params)) fail(paste0(path, ".value_params"), "must not be empty")
    if (anyDuplicated(value_params) || anyDuplicated(control_params)) fail(path, "must not repeat parameters")
    if (length(intersect(value_params, control_params))) fail(path, "value_params and control_params must be disjoint")
    for (param in c(value_params, control_params)) assert_param(param, params, paste0(path, ".params"))
    collapse <- value$collapse
    if (!is.list(collapse)) fail(paste0(path, ".collapse"), "must be an object")
    assert_names(collapse, c("param", "when", "length"), paste0(path, ".collapse"))
    if (!identical(collapse$when, "non_null") || !identical(collapse$length, "1")) fail(paste0(path, ".collapse"), "must specify non_null length 1")
    assert_param(collapse$param, params, paste0(path, ".collapse.param"))
    recycle0 <- value$recycle0
    if (!is.list(recycle0)) fail(paste0(path, ".recycle0"), "must be an object")
    assert_names(recycle0, c("param", "when", "any_value_zero"), paste0(path, ".recycle0"))
    if (!identical(recycle0$when, "true") || !identical(recycle0$any_value_zero, "zero")) fail(paste0(path, ".recycle0"), "must specify true/zero")
    assert_param(recycle0$param, params, paste0(path, ".recycle0.param"))
  } else fail(paste0(path, ".kind"), "must be zero_if_any_param_zero or recycled_values")
}
validate_scope <- function(value, params, path) {
  if (!is.list(value)) fail(path, "must be an object")
  assert_names(value, c("effect", "current_scope_when", "default_current_scope"), path)
  if (!identical(value$effect, "unknown_bindings") || !identical(value$default_current_scope, "top_level")) fail(path, "must describe top-level unknown_bindings")
  when <- value$current_scope_when
  if (!is.list(when)) fail(paste0(path, ".current_scope_when"), "must be an object")
  assert_names(when, c("param", "equals"), paste0(path, ".current_scope_when"))
  assert_param(when$param, params, paste0(path, ".current_scope_when.param"))
  if (!identical(when$equals, TRUE)) fail(paste0(path, ".current_scope_when.equals"), "must be true")
}
validate_file <- function(path) {
  doc <- jsonlite::fromJSON(path, simplifyVector = FALSE)
  if (!identical(doc$schema_version, "2")) fail(path, "must use schema_version 2")
  for (name in names(doc$functions)) {
    sig <- doc$functions[[name]]
    params <- vapply(sig$params, function(param) as_strings(if (is.character(param)) param else param$name), character(1))
    prefix <- paste0(path, ": functions.", name)
    if (!is.null(sig$predicate)) validate_predicate(sig$predicate, params, paste0(prefix, ".predicate"))
    if (!is.null(sig$assertion)) validate_assertion(sig$assertion, params, paste0(prefix, ".assertion"))
    if (!is.null(sig$return_length)) validate_return_length(sig$return_length, params, paste0(prefix, ".return_length"))
    if (!is.null(sig$conditional_scope_effect)) validate_scope(sig$conditional_scope_effect, params, paste0(prefix, ".conditional_scope_effect"))
  }
}

args <- commandArgs(trailingOnly = TRUE)
paths <- list.files(file.path(root, "stubs"), pattern = "[.]json$", recursive = TRUE, full.names = TRUE)
if ("--self-test" %in% args) {
  validate_file(file.path(root, "tests", "fixtures", "schema", "valid-function-semantics.json"))
  rejected <- tryCatch({ validate_file(file.path(root, "tests", "fixtures", "schema", "invalid-standalone-assertion.json")); FALSE }, error = function(e) TRUE)
  if (!rejected) stop("invalid standalone assertion fixture was accepted")
}
for (path in paths) validate_file(path)
cat(sprintf("Validated %d stub schema documents.\n", length(paths)))
