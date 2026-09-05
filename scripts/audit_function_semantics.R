#!/usr/bin/env Rscript

# Audit provenance for the schema-2 function-semantics declarations.  Keep
# this separate from the namespace/name audit: these facts come from R's
# actual formals and rlang's installed implementation, not from JSON shape.

script_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script_dir <- if (length(script_arg)) dirname(normalizePath(sub("^--file=", "", script_arg[[1]]))) else "."
root <- normalizePath(file.path(script_dir, ".."), mustWork = TRUE)
if (!requireNamespace("jsonlite", quietly = TRUE)) stop("audit_function_semantics.R requires jsonlite")
source(file.path(script_dir, "param_optionality.R"))

base <- jsonlite::fromJSON(file.path(root, "stubs", "base", "base.json"), simplifyVector = FALSE)
rlang_stub <- jsonlite::fromJSON(file.path(root, "stubs", "rlang", "rlang.json"), simplifyVector = FALSE)
param_names <- function(sig) vapply(sig$params, function(param) if (is.character(param)) param else param$name, character(1))
as_strings <- function(value) unlist(value, recursive = FALSE, use.names = FALSE)
expect <- function(ok, message) if (!isTRUE(ok)) stop(message, call. = FALSE)

# These are real public formals, including controls that must not be mistaken
# for recycled paste values. Semantic parameter names are formal names and are
# interpreted only after ordinary R argument binding.
verified_base_functions <- c("paste", "paste0", "source", "intersect")
for (name in verified_base_functions) {
  actual <- names(formals(get(name, envir = baseenv())))
  expect(identical(param_names(base$functions[[name]]), actual), sprintf("base::%s parameters differ from installed R", name))
}
for (path in list.files(file.path(root, "stubs"), pattern = "[.]json$", recursive = TRUE, full.names = TRUE)) {
  doc <- jsonlite::read_json(path)
  signatures <- Filter(function(sig) !is.null(sig$higher_order), doc$functions)
  if (identical(doc$package, "base")) expect(length(signatures) > 0L, "base stub must declare higher-order functions")
  if (!length(signatures)) next
  if (!requireNamespace(doc$package, quietly = TRUE)) {
    cat(sprintf("SKIP: %s higher-order formals (package not installed)\n", doc$package))
    next
  }
  for (name in names(signatures)) {
    sig <- signatures[[name]]
    label <- paste0(doc$package, "::", name)
    fn <- getExportedValue(doc$package, name)
    fn_formals <- formals(fn)
    declared <- param_names(sig)
    expect(identical(declared, names(fn_formals)), sprintf("%s parameters differ from installed R", label))
    optional_params <- missing_optional_params(fn, setdiff(declared, "..."))
    for (i in seq_along(sig$params)) {
      param <- sig$params[[i]]
      param_name <- declared[[i]]
      if (identical(param_name, "...")) next
      if (doc$package == "base") expect(is.list(param), sprintf("%s parameter %s must opt into argument matching", label, param_name))
      if (!is.list(param)) next
      has_default <- !identical(fn_formals[[param_name]], quote(expr = ))
      is_optional <- has_default || param_name %in% optional_params
      # A missing()-optional formal has no syntactic default but is omittable.
      expect(identical(isTRUE(param$default), has_default), sprintf("%s parameter %s has wrong default metadata", label, param_name))
      expect(identical(isTRUE(param$required), !is_optional), sprintf("%s parameter %s has wrong required metadata", label, param_name))
    }
  }
  cat(sprintf("Verified %d %s higher-order signatures.\n", length(signatures), doc$package))
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
source_exprs_param <- source_sig$params[[match("exprs", param_names(source_sig))]]
expect(!isTRUE(source_file_param$default) && !isTRUE(source_file_param$required), "source file must stay omittable via missing() handling, not a syntactic default")
expect(!isTRUE(source_exprs_param$default) && !isTRUE(source_exprs_param$required), "source exprs must stay omittable via missing() handling, not a syntactic default")
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
unlink(source_file)

# Defusing evaluation modes for the base quoting helpers. The distinction
# between quoted_expression and captures_promise is observable: a quoting
# helper captures the syntactic argument at its own call site, while
# substitute() defuses the promise supplied by the caller of the
# enclosing function.
expect(identical(base$functions$quote$eval, list(expr = "quoted_expression")), "base::quote must quote its expr argument")
expect(identical(base$functions$bquote$eval, list(expr = "quoted_expression")), "base::bquote must quote its expr argument")
expect(identical(base$functions$expression$eval, list("..." = "quoted_expression")), "base::expression must quote its dots")
expect(identical(base$functions$alist$eval, list("..." = "quoted_expression")), "base::alist must quote its dots")
expect(identical(base$functions$substitute$eval, list(expr = "captures_promise")), "base::substitute must capture the caller promise")
expect(identical(base$functions$delayedAssign$eval, list(value = "captures_promise")), "base::delayedAssign must capture its value promise and nothing else")

# Runtime witnesses: the quoting helpers stay literal inside a forwarding
# function, while substitute() sees through to the caller's expression.
quote_literal <- function(x) quote(x)
expect(identical(quote_literal(a + b), as.name("x")), "quote must capture its own call site, not the caller promise")
bquote_literal <- function(x) bquote(x)
expect(identical(bquote_literal(a + b), as.name("x")), "bquote must capture its own call site, not the caller promise")
expression_literal <- function(...) expression(...)
expect(identical(expression_literal(a + b)[[1]], as.name("...")), "expression must capture its own dots literally")
alist_literal <- function(...) alist(...)
expect(identical(alist_literal(a + b)[[1]], as.name("...")), "alist must capture its own dots literally")
substitute_caller <- function(x) substitute(x)
expect(identical(substitute_caller(a + b), quote(a + b)), "substitute must defuse the promise supplied by the caller")

# delayedAssign: only the value argument is captured. Installed R documents x
# as "a variable name (given as a quoted string in the function call)" and
# forces it as an ordinary argument: a bare symbol errors, and a variable's
# string value supplies the target name, so x is not a quoted_symbol and
# stays unlisted. The value promise is deferred like substitute's defusing:
# it sees through a forwarded promise instead of the literal argument.
delayed_name <- ".r_typeshed_delayed_assign_witness"
delayed_source <- delayed_name
delayedAssign(delayed_source, 1 + 1)
expect(identical(get(delayed_name), 2), "delayedAssign must force x to obtain the target name")
expect(inherits(try(delayedAssign(.r_typeshed_delayed_assign_undefined, 5), silent = TRUE), "try-error"), "delayedAssign must evaluate x as an ordinary argument")
delayed_lazy <- local({
  delayed_msg <- "old"
  delayedAssign(delayed_name, delayed_msg)
  delayed_msg <- "new"
  get(delayed_name, envir = environment(), inherits = FALSE)
})
expect(identical(delayed_lazy, "new"), "delayedAssign must defer forcing value until first access")
delayed_forward <- function(arg) {
  delayedAssign(delayed_name, arg)
  get(delayed_name, envir = environment(), inherits = FALSE)
}
expect(identical(delayed_forward(1 + 1), 2), "delayedAssign must capture the caller's forwarded promise")
rm(list = c(delayed_name, "delayed_source"))

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
# quo() defuses a missing argument into a usable empty quosure -- the
# lazyeval compatibility shims call it on their missing() branch -- so the
# stub's expr formal is curated optional, like env_get_list's default.
expect(rlang::is_quosure(rlang::quo()) && rlang::quo_is_missing(rlang::quo()), "rlang::quo() must return an empty quosure")
expect(identical(rlang_stub$functions$quo$params, list(list(name = "expr", required = FALSE))), "rlang::quo's expr formal must be optional in the stub")

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
  witness <- assertion_witnesses[[name]]
  expect(!is.null(witness), sprintf("rlang::%s has no witness value declared in this audit", name))
  expect(!inherits(try(do.call(get(name, ns), setNames(list(witness), assertion$subject_param)), silent = TRUE), "try-error"), sprintf("rlang::%s rejects its declared target witness", name))
  if (!is.null(assertion$allow_null_param)) {
    expect(!inherits(try(do.call(get(name, ns), c(list(x = NULL), setNames(list(TRUE), assertion$allow_null_param))), silent = TRUE), "try-error"), sprintf("rlang::%s allow_null does not admit NULL", name))
  }
  if (!is.null(assertion$allow_na_param)) {
    expect(!inherits(try(do.call(get(name, ns), c(list(x = NA), setNames(list(TRUE), assertion$allow_na_param))), silent = TRUE), "try-error"), sprintf("rlang::%s allow_na does not admit NA", name))
  }
}

# rlang defusing family. expr() and quo() capture the syntactic argument
# at their own call site (rlang documents expr() as equivalent to
# bquote()), while the variadic exprs() defuses the caller's forwarded
# dots like the already-declared quos()/enquos().
expect(identical(rlang_stub$functions$expr$eval, list(expr = "quoted_expression")), "rlang::expr must quote its expr argument")
expect(identical(rlang_stub$functions$quo$eval, list(expr = "quoted_expression")), "rlang::quo must quote its expr argument")
expect(identical(rlang_stub$functions$exprs$eval, list("..." = "captures_promise")), "rlang::exprs must capture the caller dots")
expr_literal <- function(x) rlang::expr(x)
expect(identical(expr_literal(a + b), as.name("x")), "rlang::expr must capture its own call site, not the caller promise")
quo_literal <- function(x) rlang::quo(x)
expect(identical(rlang::quo_get_expr(quo_literal(a + b)), as.name("x")), "rlang::quo must capture its own call site, not the caller promise")
exprs_caller <- function(...) rlang::exprs(...)
expect(identical(exprs_caller(a + b)[[1]], quote(a + b)), "rlang::exprs must defuse the caller dots")

cat(sprintf("Function-semantics provenance verified (%d standalone rlang checks).\n", length(checks)))
