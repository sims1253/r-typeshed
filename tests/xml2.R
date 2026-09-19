#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "xml2"
version <- "1.6.0"
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

# Parsing, XPath, and URL joins are offline string/document operations.
x <- xml2::read_xml("<a><b>1</b></a>")
stopifnot(inherits(x, "xml_document"))
stopifnot(identical(xml2::xml_text(xml2::xml_find_first(x, "//b")), "1"))
stopifnot(identical(xml2::xml_find_num(x, "number(//b)"), 1))
stopifnot(grepl("<a", as.character(x), fixed = TRUE))
stopifnot(grepl("<c", as.character(xml2::as_xml_document("<c><d>2</d></c>")), fixed = TRUE))
stopifnot(identical(xml2::url_absolute("b", "http://example.com/a/"),
                    "http://example.com/a/b"))
stopifnot(identical(names(xml2::url_parse("http://example.com/a/b")),
                    c("scheme", "server", "port", "user", "path", "query", "fragment")))
stopifnot(inherits(xml2::xml_missing(), "xml_missing"))
stopifnot(is(xml2::`.__C__xml_document`, "classRepresentation"))

cat("xml2 exports, formals, and document behavior verified.\n")
