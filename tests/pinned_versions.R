#!/usr/bin/env Rscript
# Regression test for the pinned-version single source of truth: the
# upstream-versions.json entries, the rendered CI installer list, and the
# oracle tests' version assertions must not be able to silently disagree.
# Uses mocked version metadata so it runs without any package installs.
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))

env <- new.env(parent = globalenv())
sys.source(file.path(root, 'scripts', 'render_ci_packages.R'), env)

# The mocked source: identical shape to upstream-versions.json, with one
# deliberate version bump that the renderer must reflect exactly.
mock <- jsonlite::read_json(file.path(root, 'upstream-versions.json'))
mock$httr <- '9.9.9'
mock_file <- tempfile(fileext = '.json')
jsonlite::write_json(mock, mock_file, auto_unbox = TRUE)

# 1. The rendered pinned list carries every CI package at its recorded
#    version -- a bump in the source must flow to the installer verbatim.
rendered <- env$render_pinned(jsonlite::read_json(mock_file))
stopifnot(identical(unname(rendered[env$ci_packages == 'httr']), 'httr@9.9.9'))
stopifnot(identical(unname(rendered[env$ci_packages == 'jsonlite']), 'jsonlite@2.0.0'))
stopifnot(identical(length(rendered), length(env$ci_packages)),
          identical(names(rendered), env$ci_packages))

# 2. Coverage cannot drift between the two jobs: pinned and drift render
#    the same package set, differing only in version pinning.
stopifnot(identical(unname(sub('@.*$', '', rendered)),
                    unname(sub('^any::', '', env$render_drift()))))

# 3. A package missing from the version source fails loudly instead of
#    installing floating latest into the reference job.
incomplete <- jsonlite::read_json(mock_file)
incomplete$scales <- NULL
bad_file <- tempfile(fileext = '.json')
jsonlite::write_json(incomplete, bad_file, auto_unbox = TRUE)
err <- tryCatch({ env$render_pinned(jsonlite::read_json(bad_file)); NULL },
                error = conditionMessage)
stopifnot(is.character(err), grepl('lacks CI packages: scales', err, fixed = TRUE))

# 4. An invalid recorded version (empty string) fails loudly too.
invalid <- jsonlite::read_json(mock_file)
invalid$glue <- ''
bad_file2 <- tempfile(fileext = '.json')
jsonlite::write_json(invalid, bad_file2, auto_unbox = TRUE)
err2 <- tryCatch({ env$render_pinned(jsonlite::read_json(bad_file2)); NULL },
                 error = conditionMessage)
stopifnot(is.character(err2), grepl('invalid recorded version for glue', err2, fixed = TRUE))

# 5. Oracle expectations agree with the source: every inventory test that
#    pins an installed version must pin the recorded reference version, so
#    a reference bump without an oracle update (or vice versa) fails here.
# install_set6_deps.R pins the archived-set installer tooling (ooplah),
# which is not an audited namespace, so it is out of this agreement check.
#
# The comparison goes through package_version objects rather than exact
# string equality: upstream-versions.json mixes spellings by construction
# (curation records the dot-normalized as.character(packageVersion()) form
# while the monthly publish step commits CRAN's canonical dash string), so
# after a dash-spelled recorded bump (zoo 1.9-0 -> 1.9-1) the exact-string
# gate failed even once the curator updated the oracle to the matching dot
# form. Same guard style as same_version in scripts/update_typeshed.R,
# defined locally so the test stays self-contained; values that do not
# parse as versions fall back to exact string comparison.
same_version <- function(a, b) {
  if (length(a) != 1L || length(b) != 1L || is.na(a) || is.na(b)) return(FALSE)
  parsed <- tryCatch(list(package_version(a), package_version(b)), error = function(error) NULL)
  if (is.null(parsed)) return(identical(a, b))
  identical(parsed[[1L]], parsed[[2L]])
}
# Fixtures: dot-vs-dash spellings of one version compare equal, a
# genuinely different version still disagrees, and unparseable values fall
# back to exact string equality in both directions.
stopifnot(same_version('1.9.0', '1.9-0'), same_version('1.9-1', '1.9.1'))
stopifnot(!same_version('1.9.0', '1.9-1'))
stopifnot(same_version('draft', 'draft'), !same_version('draft', 'other'))

oracle_tests <- setdiff(
  list.files(file.path(root, 'tests'), pattern = '[.]R$', full.names = TRUE),
  file.path(root, 'tests', 'install_set6_deps.R'))
pins <- jsonlite::read_json(file.path(root, 'upstream-versions.json'))
checked <- 0L
for (test in oracle_tests) {
  lines <- readLines(test, warn = FALSE)
  # Single-package oracles declare `version <- "x.y.z"`; the archived-set
  # oracle declares a named vector `versions <- c(set6 = "a", ... = "b")`.
  single <- regmatches(lines, regexec('^version <- "([^"]+)"$', lines))
  single <- single[vapply(single, length, integer(1)) > 0L]
  multi <- regmatches(lines, regexec('^versions <- c[(](.+)[)]$', lines))
  multi <- multi[vapply(multi, length, integer(1)) > 0L]
  if (length(single)) {
    package <- sub('[.]R$', '', basename(test))
    stopifnot(package %in% names(pins),
              same_version(single[[1L]][[2L]], pins[[package]]))
    checked <- checked + 1L
  }
  if (length(multi)) {
    pairs <- regmatches(multi[[1L]][[2L]],
                        gregexpr('[A-Za-z0-9.]+ = "[^"]+"', multi[[1L]][[2L]]))
    for (pair in pairs[[1L]]) {
      kv <- regmatches(pair, regexec('([A-Za-z0-9.]+) = "([^"]+)"', pair))[[1L]]
      stopifnot(kv[[2L]] %in% names(pins), same_version(kv[[3L]], pins[[kv[[2L]]]]))
      checked <- checked + 1L
    }
  }
}
stopifnot(checked >= 12L)  # single-package + archived-set pins all covered

cat(sprintf('pinned-version source, renderer, and %d oracle expectations agree\n', checked))
