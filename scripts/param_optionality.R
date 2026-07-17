# Determine which no-default formals are optional by convention in an R
# function body.  Keep this deliberately narrow: it is a generator heuristic,
# not an attempt to infer arbitrary control flow or promise forcing.

call_name <- function(expr) {
  head <- expr[[1L]]
  if (is.symbol(head)) return(as.character(head))
  if (is.call(head) && identical(as.character(head[[1L]]), "::") && length(head) == 3L) {
    return(as.character(head[[3L]]))
  }
  ""
}

missing_optional_params <- function(fn, params = names(formals(fn))) {
  if (is.null(params) || !length(params)) return(character())
  expr <- body(fn)
  # all.names() is an inexpensive AST prefilter; the walk below verifies that
  # missing()/maybe_missing() actually receive the formal in question.
  names_in_body <- all.names(expr, functions = TRUE, unique = TRUE)
  has_nargs_name <- "nargs" %in% names_in_body
  if (!has_nargs_name && !any(c("missing", "maybe_missing") %in% names_in_body)) {
    return(character())
  }

  optional <- character()
  has_nargs_call <- FALSE
  walk <- function(node) {
    if (missing(node)) return(invisible())
    if (is.call(node)) {
      name <- call_name(node)
      if (identical(name, "nargs") && length(node) == 1L) has_nargs_call <<- TRUE
      if (name %in% c("missing", "maybe_missing") && length(node) >= 2L && is.symbol(node[[2L]])) {
        candidate <- as.character(node[[2L]])
        if (candidate %in% params) optional <<- c(optional, candidate)
      }
      for (child in as.list(node)[-1L]) walk(child)
    } else if (is.pairlist(node) || is.expression(node) || is.list(node)) {
      for (child in node) walk(child)
    }
  }
  walk(expr)

  # nargs() dispatch conventionally makes the trailing no-default formals
  # optional.  Without control-flow inference we conservatively mark only the
  # no-default candidates supplied by the caller.
  if (has_nargs_call) optional <- c(optional, params)
  unique(optional)
}
