#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "data.table"
version <- "1.18.6.1"
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)
# Constructors that always return exactly c("data.table", "data.frame")
# are typed as one, so a consumer can scope `dt[val > 1]` to the table's
# columns. The rest stay opaque: fread(data.table = FALSE) returns a
# plain data.frame, copy() copies any object, as.data.table() is an S3
# generic whose methods may return anything, and setDT() keeps the
# classes that follow "data.frame".
table <- list(mode = "list", length = "unknown", na = TRUE,
              class = list("data.table", "data.frame"))
constructors <- c("data.table", "rbindlist", "CJ", "SJ")
# These capture their column-name arguments with substitute() instead of
# evaluating them. setkeyv(), setindexv(), and setorderv() take character
# vectors and evaluate them. setindex() and measure() quote only part of
# their `...`: setindex(...) forwards the evaluated table and `verbose`
# to setkey(), and measure() evaluates its named arguments. The schema
# cannot mark part of `...`, so the quoted mode covers the column names
# and leaves those other arguments unchecked.
quoted <- list(
  setkey = list(`...` = "quoted_expression"),
  setindex = list(`...` = "quoted_expression"),
  setorder = list(`...` = "quoted_expression"),
  frank = list(`...` = "quoted_expression"),
  measure = list(`...` = "quoted_expression"),
  substitute2 = list(expr = "quoted_expression")
)

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
# data.table ships no lazy data at this version -- its only exported
# non-function values are the [.data.table frame symbols (.SD, .BY,
# .N, .I, .GRP, .NGRP, .ROW, .EACHI), .Last.updated, and the three S4
# class values below -- but lazy datasets resolve through :: without
# appearing in the namespace export list (scripts/audit_typeshed.R
# resolves them the same way), so the value inventory unions the
# lazy-data database anyway. A future upstream flip cannot then widen
# the :: surface silently.
lazydata <- asNamespace(pkg)$.__NAMESPACE__.$lazydata
datasets <- setdiff(ls(lazydata, all.names = TRUE), functions)
values <- union(values, datasets)
stopifnot(setequal(names(doc$functions), functions))
stopifnot(setequal(names(doc$datasets), values))
for (name in functions) {
  sig <- doc$functions[[name]]
  stopifnot(identical(sig$params, as.list(names(formals(getExportedValue(pkg, name))))))
  expected <- if (name %in% constructors) table else opaque
  stopifnot(identical(sig$return, expected))
  stopifnot(identical(sig$eval, quoted[[name]]))
}
for (name in values) {
  stopifnot(!is.function(getExportedValue(pkg, name)))
  stopifnot(identical(doc$datasets[[name]], opaque))
}

# The inventory claims no [.data.table semantics beyond name/formal
# resolution, the constructor classes, and the quoted arguments above --
# the :=/`j` NSE surface is deliberately out of scope for
# an inventory stub (#43) -- but the exported API the inventory names
# keeps its documented behavior: construction, by-reference :=, grouped
# aggregation over .N, and keys.
dt <- data.table::data.table(g = c("a", "a", "b"), x = 1:3)
stopifnot(data.table::is.data.table(dt), is.data.frame(dt),
          identical(data.table::key(dt), NULL))
dt[, y := x * 2L]
stopifnot(identical(dt$y, c(2L, 4L, 6L)))
agg <- dt[, .(s = sum(x), n = .N), by = g]
stopifnot(identical(agg$s, c(3L, 3L)), identical(agg$n, c(2L, 1L)))
data.table::setkey(dt, g)
stopifnot(identical(data.table::key(dt), "g"),
          identical(dt["b", x, on = "g"], 3L))
stopifnot(identical(nrow(data.table::CJ(a = 1:2, b = 1:3)), 6L))
stopifnot(identical(data.table::`%between%`(2L, c(1L, 3L)), TRUE),
          identical(data.table::`%chin%`("a", c("a", "b")), TRUE))

# Live-R witnesses for the typed constructor returns, including empty
# inputs and inputs that carry an extra class, and for the opaque
# exceptions.
# data.table() drops the extra class from its argument by reference, so
# each call gets a fresh object.
extra <- function() structure(data.frame(a = 1), class = c("data.frame", "extra"))
witnesses <- list(
  data.table::data.table(a = 1),
  data.table::data.table(),
  data.table::data.table(extra()),
  data.table::rbindlist(list(list(a = 1))),
  data.table::rbindlist(list()),
  data.table::rbindlist(list(extra())),
  data.table::CJ(1:2, 3:4),
  data.table::SJ(1:2)
)
for (w in witnesses) {
  stopifnot(identical(class(w), c("data.table", "data.frame")), is.list(w))
}
stopifnot(identical(class(data.table::fread(text = "a\n1", data.table = FALSE)),
                    "data.frame"))
stopifnot(identical(class(data.table::setDT(extra())),
                    c("data.table", "data.frame", "extra")))
registerS3method("as.data.table", "rts_probe", function(x, ...) 42L,
                 envir = asNamespace("data.table"))
stopifnot(identical(data.table::as.data.table(structure(1, class = "rts_probe")), 42L))

# Live-R witnesses for the quoted arguments: these column names are
# not bound in the calling frame (measure()'s `dim` names a column even
# though base::dim exists).
stopifnot(!exists("g2"), !exists("x2"), !exists("value.name"),
          !exists("undefined_name"))
q <- data.table::data.table(g2 = c("b", "a"), x2 = 2:1)
data.table::setkey(q, g2)
stopifnot(identical(data.table::key(q), "g2"))
data.table::setindex(q, x2)
stopifnot(identical(data.table::indices(q), "x2"))
data.table::setorder(q, -x2)
stopifnot(identical(q$x2, 2:1))
stopifnot(identical(data.table::frank(q, x2), c(2, 1)))
wide <- data.table::data.table(id = 1L, a_1 = 1, a_2 = 2)
long <- data.table::melt(wide, measure.vars = data.table::measure(value.name, dim, sep = "_"))
stopifnot(identical(names(long), c("id", "dim", "a")))
# The evaluated parts of setindex()'s and measure()'s `...`.
stopifnot(!exists("missing_table"), !exists("missing_conversion"))
stopifnot(inherits(try(data.table::setindex(missing_table, x2), silent = TRUE),
                   "try-error"),
          inherits(try(data.table::measure(value.name, dim = missing_conversion,
                                           cols = c("a_1", "a_2")),
                       silent = TRUE),
                   "try-error"))
stopifnot(identical(data.table::substitute2(undefined_name + 1, list()),
                    quote(undefined_name + 1)))

# fread/fwrite round-trip the same values through text.
f <- tempfile(fileext = ".csv")
data.table::fwrite(dt, f)
back <- data.table::fread(f)
stopifnot(data.table::is.data.table(back),
          identical(back$x, dt$x), identical(back$g, dt$g))
unlink(f)

# The three .__C__* exported values are the S4 class definitions the
# IDate/ITime/data.table classes register; the frame symbols resolve
# as non-function values, and .Last.updated counts by-reference updates.
stopifnot(inherits(data.table::as.IDate("2026-01-02"), "IDate"),
          inherits(data.table::as.ITime("01:02:03"), "ITime"),
          isS4(data.table:::`.__C__data.table`),
          is.integer(data.table:::.Last.updated))

cat("data.table exports, formals, frame symbols, and core behavior verified.\n")
