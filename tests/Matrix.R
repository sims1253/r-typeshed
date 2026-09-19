#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "Matrix"
version <- "1.7.6"
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
# Lazy datasets resolve through :: via the namespace lazydata fallback
# (the ggplot2 oracle unions it in), but Matrix ships LazyData: no --
# upstream's LazyDataNote: "not possible, since we use data/*.R and our
# S4 classes" -- so CAex/KNex/USCounties/wrld_1deg are data()-only and
# the fallback contributes nothing here. Union it anyway so a future
# upstream flip cannot widen the :: surface silently, and pin the current
# behavior: the four load through data() as non-functions but error
# under getExportedValue.
lazydata <- ls(asNamespace(pkg)$.__NAMESPACE__.$lazydata, all.names = TRUE)
stopifnot(identical(lazydata, character()))
datasets <- c("CAex", "KNex", "USCounties", "wrld_1deg")
for (name in datasets) {
  error <- tryCatch(getExportedValue(pkg, name), error = identity)
  stopifnot(inherits(error, "error"))
}
env <- new.env(parent = globalenv())
data(list = datasets, package = pkg, envir = env)
for (name in datasets) {
  stopifnot(!is.function(get(name, envir = env)))
}
values <- union(setdiff(exports, functions), lazydata)
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

# Constructors pick the documented S4 classes and the exported generics
# dispatch on them: dense and sparse Matrix(), Diagonal() read back through
# the diag generic, crossprod() returning a symmetric matrix.
m <- Matrix::Matrix(1:4, nrow = 2)
stopifnot(identical(dim(m), c(2L, 2L)), inherits(m, "dgeMatrix"))
sm <- Matrix::Matrix(1:4, nrow = 2, sparse = TRUE)
stopifnot(inherits(sm, "dgCMatrix"), identical(Matrix::colSums(sm), c(3, 7)))
d <- Matrix::Diagonal(x = c(1, 2))
stopifnot(identical(dim(d), c(2L, 2L)), inherits(d, "ddiMatrix"),
          identical(Matrix::diag(d), c(1, 2)), identical(sum(Matrix::diag(d)), 3))
cp <- Matrix::crossprod(m)
stopifnot(identical(dim(cp), c(2L, 2L)), isTRUE(Matrix::isSymmetric(cp)),
          identical(as.matrix(cp), matrix(c(5, 11, 11, 25), nrow = 2)))

cat("Matrix exports, formals, and matrix construction verified.\n")
