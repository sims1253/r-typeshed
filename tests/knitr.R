#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "knitr"
version <- "1.52"
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)

# The upstream-drift CI job sets RT_TYPESHED_DRIFT so its probes reach the
# behavioral export/formal checks even when CRAN has moved past this
# recorded reference version; the required generators job never sets it.
if (Sys.getenv("RT_TYPESHED_DRIFT") == "") {
  stopifnot(identical(as.character(packageVersion(pkg)), version))
}
doc <- jsonlite::read_json(file.path(root, "stubs", pkg, paste0(pkg, ".json")))
exports <- getNamespaceExports(pkg)
functions <- exports[vapply(exports, function(name) {
  is.function(getExportedValue(pkg, name))
}, logical(1))]
values <- setdiff(exports, functions)
# knitr ships no lazy data at this version -- its only exported
# non-function values are the opts/hooks objects, patterns, and rand_seed
# below -- but lazy datasets resolve through :: without appearing in the
# namespace export list (scripts/audit_typeshed.R resolves them the same
# way), so the value inventory unions the lazy-data database anyway. A
# future upstream flip cannot then widen the :: surface silently.
lazydata <- asNamespace(pkg)$.__NAMESPACE__.$lazydata
datasets <- setdiff(ls(lazydata, all.names = TRUE), functions)
values <- union(values, datasets)
stopifnot(setequal(names(doc$functions), functions))
stopifnot(setequal(names(doc$datasets), values))
for (name in functions) {
  sig <- doc$functions[[name]]
  stopifnot(identical(sig$params, as.list(names(formals(getExportedValue(pkg, name))))))
  stopifnot(identical(sig$return, opaque))
}
for (name in values) {
  stopifnot(!is.function(getExportedValue(pkg, name)))
  stopifnot(identical(doc$datasets[[name]], opaque))
}

# knit() evaluates inline code and R chunks from in-memory text and
# returns the sewn output: an inline `r 1 + 1` renders its value, and a
# chunk's value appears behind the default comment marker.
inline <- knitr::knit(text = "Value: `r 1 + 1`.", quiet = TRUE)
stopifnot(identical(inline, "Value: 2."))
chunked <- knitr::knit(text = c("```{r}", "40 + 2", "```"), quiet = TRUE)
stopifnot(is.character(chunked),
          any(grepl("## [1] 42", chunked, fixed = TRUE)))
stopifnot(identical(knitr::knit_expand(text = "value={{1 + 1}}"), "value=2"))
stopifnot(identical(as.character(knitr::combine_words(c("a", "b", "c"))),
                    "a, b, and c"))

# Tables and raw asis output keep their documented shapes: a pipe kable
# is a knitr_kable whose rows are the rendered cells, and asis_output
# marks its input knit_asis without changing the text.
tab <- knitr::kable(data.frame(a = 1:2, b = c("x", "y")), format = "pipe")
stopifnot(inherits(tab, "knitr_kable"),
          identical(attr(tab, "format"), "pipe"),
          identical(as.character(tab)[[3]], "|  1|x  |"))
asis <- knitr::asis_output("**bold**")
stopifnot(inherits(asis, "knit_asis"), identical(as.character(asis), "**bold**"))

# The mixed API is the reason these exports are values, not functions:
# ten `new_defaults` objects -- the five opts_* option stores plus
# cache_engines, knit_code, knit_engines, knit_hooks, and knit_patterns
# -- are plain lists of get/set/delete/append/merge/restore/lock
# closures, closed over their store. knit_theme keeps the older
# two-member set/get shape, all_patterns is a plain pattern list, and
# rand_seed is the quoted seed expression itself. Recorded as opaque
# dataset values like the set6/scales R6 generators, they verify here
# as the live objects rather than callables.
defaults <- c("cache_engines", "knit_code", "knit_engines", "knit_hooks",
              "knit_patterns", "opts_chunk", "opts_current", "opts_hooks",
              "opts_knit", "opts_template")
members <- c("get", "set", "delete", "append", "merge", "restore", "lock")
for (name in defaults) {
  store <- getExportedValue(pkg, name)
  stopifnot(is.list(store), identical(names(store), members),
            all(vapply(store, is.function, logical(1))))
}
stopifnot(is.list(knitr::knit_theme),
          identical(names(knitr::knit_theme), c("set", "get")),
          is.function(knitr::knit_theme$set), is.function(knitr::knit_theme$get))
stopifnot(identical(names(knitr::all_patterns),
                    c("rnw", "brew", "tex", "html", "md", "rst",
                      "asciidoc", "textile", "typst")))
stopifnot(is.call(knitr::rand_seed))

# The stores actually round-trip: setting a chunk option reads back
# through $get and restores, the default hooks are functions, and
# engine registration -- the knit_engines$set() call every custom
# engine starts with -- installs and deletes a probe engine.
old_echo <- knitr::opts_chunk$get("echo")
knitr::opts_chunk$set(echo = FALSE)
stopifnot(identical(knitr::opts_chunk$get("echo"), FALSE))
knitr::opts_chunk$set(echo = old_echo)
stopifnot(identical(knitr::opts_chunk$get("echo"), old_echo))
hooks <- knitr::knit_hooks$get(c("source", "output", "plot"))
stopifnot(all(vapply(hooks, is.function, logical(1))))
html_hooks <- knitr::hooks_html()
stopifnot(identical(names(html_hooks),
                    c("source", "output", "warning", "message",
                      "error", "plot", "chunk", "inline")),
          all(vapply(html_hooks, is.function, logical(1))))
stopifnot(is.function(knitr::knit_engines$get("R")))
knitr::knit_engines$set(probe_engine_xyz = function(options) "probe")
stopifnot(is.function(knitr::knit_engines$get("probe_engine_xyz")))
knitr::knit_engines$delete("probe_engine_xyz")
stopifnot(is.null(knitr::knit_engines$get("probe_engine_xyz")))

# all_labels() captures its filters with match.call() and evaluates them
# against each chunk's options, so a bare option name such as `engine` or
# `echo` needs no binding in the caller; all_rcpp_labels() forwards its
# `...` to it. Inside a knit, `!echo` selects only the echo = FALSE chunk.
stopifnot(!exists("engine"), !exists("echo"))
labels_doc <- c("```{r first}", "1", "```",
                "```{r second, echo=FALSE}", "2", "```",
                "```{r probe}",
                "cat('labels:', knitr::all_labels(!echo), knitr::all_rcpp_labels(echo), '\\n')",
                "```")
labelled <- knitr::knit(text = labels_doc, quiet = TRUE)
stopifnot(grepl("## labels: second\n", labelled, fixed = TRUE))

cat("knitr exports, formals, opts/hooks objects, and knitting verified.\n")
