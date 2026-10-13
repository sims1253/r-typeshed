#!/usr/bin/env Rscript
# Verify the mirai stub contract against the installed package: exports,
# formal order and requiredness, the .expr capture, and the return claims.
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
pkg <- "mirai"
version <- "2.7.3"

# The upstream-drift CI job sets RT_TYPESHED_DRIFT so its probes reach the
# behavioral checks even when CRAN has moved past this recorded version.
if (Sys.getenv("RT_TYPESHED_DRIFT") == "") {
  stopifnot(identical(as.character(packageVersion(pkg)), version))
}
doc <- jsonlite::read_json(file.path(root, 'stubs/mirai/mirai.json'))
sig <- doc$functions$status

library(mirai)
stopifnot(identical(unlist(sig$params), '.compute'))
stopifnot(identical(names(formals(mirai::status)), '.compute'))
stopifnot(identical(sig$return$mode, 'list'))

# Runtime shape: named list; connections/daemons always present.
daemons(1, sync = TRUE)
status_value <- status()
stopifnot(is.list(status_value), identical(names(status_value)[1], 'connections'))
stopifnot(is.integer(status_value$connections), is.character(status_value$daemons))
# A dollar access on the result must be valid R.
stopifnot(is.integer(status_value$connections))
daemons(0)

# Exports: every exported function has a signature; the exported bytecode
# option values (.flat, .progress, .stop) are non-callable datasets.
exports <- getNamespaceExports(pkg)
is_fun <- vapply(exports, function(name) is.function(getExportedValue(pkg, name)), logical(1))
stopifnot(setequal(names(doc$functions), exports[is_fun]))
stopifnot(setequal(names(doc$datasets), exports[!is_fun]))
stopifnot(setequal(names(doc$datasets), c('.flat', '.progress', '.stop')))
for (name in names(doc$datasets)) {
  value <- getExportedValue(pkg, name)
  stopifnot(!is.function(value), identical(length(value), 1L))
  stopifnot(identical(doc$datasets[[name]][c('mode', 'length', 'na')],
                      list(mode = 'opaque', length = '1', na = FALSE)))
}

# Formals: the stub lists every formal in order. A parameter marked required
# has no default and the call fails without it; the remaining formals
# without defaults (daemons/make_cluster `n`, `...`) are optional.
param_name <- function(p) if (is.list(p)) p$name else p
param_required <- function(p) is.list(p) && isTRUE(p$required)
no_default <- function(f) {
  names(f)[vapply(f, function(x) identical(x, quote(expr = )), logical(1))]
}
for (name in names(doc$functions)) {
  params <- doc$functions[[name]]$params
  f <- formals(getExportedValue(pkg, name))
  stopifnot(identical(vapply(params, param_name, ''), names(f) %||% character()))
  required <- vapply(params, param_name, '')[vapply(params, param_required, logical(1))]
  stopifnot(all(required %in% no_default(f)))
  stopifnot(setequal(required, setdiff(no_default(f), c('...', 'n'))) ||
              all(!vapply(params, is.list, logical(1))))
}
expected_required <- list(
  call_mirai = 'x', collect_mirai = 'x', daemons = character(),
  everywhere = '.expr', mirai = '.expr', mirai_map = c('.x', '.f'),
  stop_mirai = 'x', try_mirai = '.expr', unresolved = 'x', is_mirai = 'x'
)
for (name in names(expected_required)) {
  params <- doc$functions[[name]]$params
  required <- vapply(params, param_name, '')[vapply(params, param_required, logical(1))]
  stopifnot(identical(required, expected_required[[name]]))
}
# daemons(url = ...) works without n, while daemons() errors without it.
stopifnot(inherits(try(daemons(), silent = TRUE), 'try-error'))
stopifnot(inherits(try(mirai(), silent = TRUE), 'try-error'))
stopifnot(inherits(try(mirai_map(1:2), silent = TRUE), 'try-error'))

# .expr capture: mirai(), try_mirai(), and everywhere() substitute() their
# own call-site expression and never evaluate it in the caller; `...` goes
# through list(...) and is evaluated in the caller, so it is not quoted.
for (name in c('mirai', 'try_mirai', 'everywhere')) {
  stopifnot(identical(doc$functions[[name]]$eval, list(.expr = 'quoted_expression')))
}
for (name in setdiff(names(doc$functions), c('mirai', 'try_mirai', 'everywhere'))) {
  stopifnot(is.null(doc$functions[[name]]$eval))
}
daemons(1, sync = TRUE)
stopifnot(identical(mirai(a + b, a = 1, b = 2)[], 3))
stopifnot(identical(try_mirai(a * 2, a = 21)[], 42))
deferred <- mirai(stop('evaluated on the daemon'))
stopifnot(is_mirai_error(deferred[]))
stopifnot(inherits(try(mirai(a, a = stop('caller')), silent = TRUE), 'try-error'))
# A symbol bound to a language object in the caller is replaced by it.
captured <- quote(1 + 1)
stopifnot(identical(mirai(captured)[], 2))
forward <- function(y) mirai(y)
stopifnot(identical(forward(quote(2 + 2))[], 4))
# The one caller-side evaluation: a bare symbol bound in the calling frame is
# forced to test is.language(), so a forwarded formal's promise runs there.
# Any other expression, including one using that formal, is shipped as is.
stopifnot(inherits(try(forward(stop('forced')), silent = TRUE), 'try-error'))
shipped <- function(y) mirai(y + 1)
stopifnot(is_mirai_error(shipped(stop('not forced'))[]))

# Returns of the pre-existing entries.
ret <- function(name) doc$functions[[name]]$return
m <- mirai(NA_real_)
stopifnot(identical(class(m), c('mirai', 'recvAio')), is.environment(m))
stopifnot(identical(ret('mirai')$class, list('mirai', 'recvAio')),
          identical(ret('mirai')$length, 'unknown'))
stopifnot(identical(call_mirai(m), m), identical(call_mirai(NA), NA))
stopifnot(identical(ret('call_mirai'), 'arg0'))
na_value <- collect_mirai(m)
stopifnot(is.double(na_value), identical(length(na_value), 1L), is.na(na_value))
stopifnot(isTRUE(ret('collect_mirai')$na))
stopifnot(identical(unresolved(m), FALSE), identical(unresolved(1), FALSE))
stopifnot(identical(ret('unresolved')[c('mode', 'length', 'na')],
                    list(mode = 'logical', length = '1', na = FALSE)))
stopped <- stop_mirai(mirai(1))
stopifnot(is.logical(stopped), identical(length(stopped), 1L), !anyNA(stopped))
stopped_map <- stop_mirai(mirai_map(1:3, identity))
stopifnot(is.logical(stopped_map), identical(length(stopped_map), 3L))
stopifnot(identical(ret('stop_mirai')[c('mode', 'length', 'na')],
                    list(mode = 'logical', length = 'unknown', na = FALSE)))
ev <- everywhere(1L)
stopifnot(identical(class(ev), 'mirai_map'), identical(ret('everywhere')$class, list('mirai_map')))
stopifnot(is_mirai(try_mirai(1)), identical(ret('try_mirai')$mode, 'opaque'))
# mirai_map length follows the elements of a vector/list but the rows of a
# data frame or matrix, so it is unknown rather than arg0 or fixed.
stopifnot(identical(length(mirai_map(integer(), identity)), 0L))
stopifnot(identical(length(mirai_map(list(a = 1, b = 2), identity)), 2L))
stopifnot(identical(length(mirai_map(data.frame(a = 1:4, b = 4:1), function(a, b) a)), 4L))
stopifnot(identical(length(mirai_map(matrix(1:6, 3), function(a, b) a)), 3L))
stopifnot(identical(class(mirai_map(1:2, identity)), 'mirai_map'))
stopifnot(identical(ret('mirai_map')[c('mode', 'length', 'class')],
                    list(mode = 'opaque', length = 'unknown', class = list('mirai_map'))))
# daemons(): classed TRUE when set, unclassed FALSE when reset.
stopifnot(identical(ret('daemons')[c('mode', 'length', 'na')],
                    list(mode = 'logical', length = '1', na = FALSE)))
stopifnot(is.null(ret('daemons')$class))
reset <- daemons(0)
stopifnot(identical(reset, FALSE))
set <- daemons(1, sync = TRUE)
stopifnot(isTRUE(unclass(set)), identical(class(set), c('miraiDaemons', 'default')))

# Returns of the entries added for 2.7.3.
lgl1 <- list(mode = 'logical', length = '1', na = FALSE)
scalar_flag <- function(x) is.logical(x) && identical(length(x), 1L) && !is.na(x)
probes <- list(
  is_error_value = list(is_error_value(c(1, 2)), is_error_value(deferred[])),
  is_mirai_error = list(is_mirai_error(1), is_mirai_error(deferred[])),
  is_mirai_interrupt = list(is_mirai_interrupt(1)),
  is_mirai_map = list(is_mirai_map(ev), is_mirai_map(list())),
  daemons_set = list(daemons_set()),
  on_daemon = list(on_daemon(), mirai(mirai::on_daemon())[]),
  require_daemons = list(require_daemons())
)
for (name in names(probes)) {
  stopifnot(all(vapply(probes[[name]], scalar_flag, logical(1))))
  stopifnot(identical(ret(name), lgl1))
}
fixed_lists <- list(remote_config = remote_config(), cluster_config = cluster_config(),
                    http_config = http_config(),
                    serial_config = serial_config('cls', function(x) serialize(x, NULL), unserialize))
for (name in names(fixed_lists)) {
  value <- fixed_lists[[name]]
  stopifnot(is.list(value), !is.object(value))
  stopifnot(identical(ret(name), list(mode = 'list', length = as.character(length(value)), na = FALSE)))
}
stopifnot(identical(vapply(fixed_lists, length, integer(1)),
                    c(remote_config = 5L, cluster_config = 4L, http_config = 8L, serial_config = 3L)))
url <- local_url()
stopifnot(is.character(url), identical(length(url), 1L), !is.na(url))
stopifnot(identical(ret('local_url'), list(mode = 'character', length = '1', na = FALSE)))
daemons(0)
stopifnot(identical(daemons_set(), FALSE))
null0 <- list(mode = 'null', length = '0', na = FALSE)
stopifnot(is.null(register_serial('rt_typeshed_probe', function(x) serialize(x, NULL), unserialize)))
stopifnot(identical(ret('register_serial'), null0))
cl <- make_cluster(1)
stopifnot(is.null(stop_cluster(cl)), identical(ret('stop_cluster'), null0))

cat('mirai exports, formals, .expr capture, and return contracts verified.\n')
