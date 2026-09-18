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
stopifnot(identical(unname(rendered[env$ci_packages == 'httr']), 'any::httr@9.9.9'))
stopifnot(identical(unname(rendered[env$ci_packages == 'jsonlite']), 'any::jsonlite@2.0.0'))
stopifnot(identical(length(rendered), length(env$ci_packages)),
          identical(names(rendered), env$ci_packages))

# 2. Coverage cannot drift between the two jobs: pinned and drift render
#    the same package set, differing only in version pinning.
stopifnot(identical(unname(sub('@.*$', '', sub('^any::', '', rendered))),
                    unname(sub('^any::', '', env$render_drift()))) ||
          identical(sub('@.*$', '', sub('^any::', '', rendered)),
                    sub('^any::', '', env$render_drift())))

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
oracle_tests <- list.files(file.path(root, 'tests'), pattern = '[.]R$', full.names = TRUE)
pins <- jsonlite::read_json(file.path(root, 'upstream-versions.json'))
checked <- 0L
for (test in oracle_tests) {
  lines <- readLines(test, warn = FALSE)
  m <- regmatches(lines, regexec('^version <- "([^"]+)"$', lines))
  m <- m[vapply(m, length, integer(1)) > 0L]
  if (!length(m)) next
  package <- sub('[.]R$', '', basename(test))
  stopifnot(package %in% names(pins),
            identical(m[[1L]][[2L]], pins[[package]]))
  checked <- checked + 1L
}
stopifnot(checked >= 10L)  # the inventory oracle tests all pin versions

cat(sprintf('pinned-version source, renderer, and %d oracle expectations agree\n', checked))
