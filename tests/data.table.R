#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "data.table"
version <- "1.18.6.1"
opaque <- list(mode = "opaque", length = "unknown", na = TRUE)
# Constructors that always return a data.table are typed as one, so a
# consumer can scope `dt[val > 1]` to the table's columns. fread() stays
# opaque because fread(data.table = FALSE) returns a plain data.frame,
# and copy() returns a copy of any object.
table <- list(mode = "list", length = "unknown", na = TRUE,
              class = list("data.table", "data.frame"))
constructors <- c("data.table", "as.data.table", "rbindlist", "setDT", "CJ", "SJ")

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
}
for (name in values) {
  stopifnot(!is.function(getExportedValue(pkg, name)))
  stopifnot(identical(doc$datasets[[name]], opaque))
}

# The inventory claims no [.data.table semantics beyond name/formal
# resolution and the constructor classes -- the :=/`j` NSE surface is deliberately out of scope for
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

# Live-R witnesses for the typed constructor returns, including the
# empty and coerced inputs, and for the fread() exception.
witnesses <- list(
  data.table::data.table(a = 1),
  data.table::data.table(),
  data.table::as.data.table(list(a = 1)),
  data.table::as.data.table(matrix(1:4, 2)),
  data.table::as.data.table(data.frame(a = 1)),
  data.table::rbindlist(list(list(a = 1))),
  data.table::rbindlist(list()),
  data.table::setDT(list(a = 1)),
  data.table::CJ(1:2, 3:4),
  data.table::SJ(1:2)
)
for (w in witnesses) {
  stopifnot(identical(class(w), c("data.table", "data.frame")), is.list(w))
}
stopifnot(identical(class(data.table::fread(text = "a\n1", data.table = FALSE)),
                    "data.frame"))

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
