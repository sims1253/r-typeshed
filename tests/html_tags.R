#!/usr/bin/env Rscript
script <- sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[[1]])
root <- dirname(dirname(normalizePath(script)))
for (package in c('htmltools', 'shiny')) {
  doc <- jsonlite::read_json(file.path(root, 'stubs', package, paste0(package, '.json')))
  stopifnot('tags' %in% getNamespaceExports(package))
  stopifnot(is.null(doc$functions$tags))
  stopifnot(identical(doc$datasets$tags, list(mode = 'list', length = 'unknown', na = FALSE)))
  tags <- getExportedValue(package, 'tags')
  stopifnot(is.list(tags), !is.function(tags), all(vapply(tags, is.function, logical(1))))
  value <- tags$div(id = 'checked', tags$span('ok'))
  stopifnot(inherits(value, 'shiny.tag'), identical(value$name, 'div'),
            identical(value$attribs$id, 'checked'),
            identical(value$children[[1]]$name, 'span'))
}
stopifnot(identical(htmltools::tags, shiny::tags))
# A lexical value named tags still wins over an attached exported value.
local({
  tags <- 1L
  stopifnot(inherits(try(tags$div, silent = TRUE), 'try-error'))
})
stopifnot(inherits(try(htmltools::tags(), silent = TRUE), 'try-error'))
cat('htmltools/shiny exported tag lists and ordinary lookup controls passed\n')
