#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "curl"
version <- "8.0.0"
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

# URL parsing, escaping, handle construction, and the option catalog are
# purely local: none of these spot-checks opens a connection, so the
# oracle stays offline. (The deprecated `parse_url` spelling is no longer
# exported; `curl_parse_url` is the 8.0.0 name.)
url <- curl::curl_parse_url("https://user@example.com:8443/a?b=1#frag")
stopifnot(is.list(url), identical(names(url), c(
  "url", "scheme", "host", "port", "path", "fragment", "user", "params")))
stopifnot(
  identical(url$scheme, "https"),
  identical(url$host, "example.com"),
  identical(url$port, "8443"),
  identical(url$path, "/a"),
  identical(url$user, "user"),
  identical(url$fragment, "frag"))
stopifnot(identical(curl::curl_escape("a b"), "a%20b"))
stopifnot(identical(curl::curl_unescape("a%20b"), "a b"))
handle <- curl::new_handle()
stopifnot(inherits(handle, "curl_handle"))
options <- curl::curl_options()
stopifnot(is.integer(options), length(options) > 0L, !is.null(names(options)))
libcurl <- curl::curl_version()
stopifnot(is.list(libcurl), is.character(libcurl$version), nzchar(libcurl$version))
stopifnot(identical(curl::CURLAUTH_BASIC, 1L))
stopifnot(identical(curl::CURL_HTTP_VERSION_NONE, 0L))

cat("curl exports, formals, and offline URL behavior verified.\n")
