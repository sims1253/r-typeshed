#!/usr/bin/env Rscript
# Compare the bundled inventory with the installed CRAN namespace.
args <- grep("^--file=", commandArgs(FALSE), value = TRUE)
root <- dirname(dirname(normalizePath(sub("^--file=", "", args[[1]]))))
pkg <- "lubridate"
version <- "1.9.5"
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
# lubridate ships `lakers` as lazy data: it is public through :: without
# appearing in the namespace export list (scripts/audit_typeshed.R resolves
# it the same way), so the value inventory unions the lazy-data database.
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

# Parsers build the documented Date/POSIXct values and the component
# accessors read them back: 2024 is a leap year, 2024-02-29 is day 60 and
# a Thursday (wday 5 with Sunday = 1), asserted numerically rather than
# through a locale-dependent weekday label.
d <- lubridate::ymd("2024-02-29")
stopifnot(inherits(d, "Date"),
          identical(lubridate::year(d), 2024),
          identical(lubridate::month(d), 2),
          identical(lubridate::day(d), 29L),
          identical(lubridate::yday(d), 60),
          identical(lubridate::wday(d), 5),
          isTRUE(lubridate::leap_year(d)),
          identical(unname(lubridate::days_in_month(d)), 29L))
stopifnot(identical(lubridate::`year<-`(lubridate::ymd("2024-02-15"), 2023L),
                    as.Date("2023-02-15")))
dt <- lubridate::ymd_hms("2024-02-29 12:34:56", tz = "UTC")
stopifnot(inherits(dt, "POSIXct"),
          identical(lubridate::tz(dt), "UTC"),
          identical(lubridate::hour(dt), 12L),
          identical(lubridate::minute(dt), 34L),
          identical(lubridate::second(dt), 56),
          identical(lubridate::as_date(dt), as.Date("2024-02-29")),
          identical(lubridate::floor_date(dt, "month"),
                    lubridate::ymd_hms("2024-02-01 00:00:00", tz = "UTC")))

# The three timespan classes stay distinct: a duration is an exact number
# of seconds, %m+% rolls a month addition back to the last valid day, and
# an interval knows its length and contains its interior instants.
dur <- lubridate::duration(2, "days")
stopifnot(lubridate::is.duration(dur), !lubridate::is.period(dur),
          identical(as.numeric(dur), 172800),
          identical(lubridate::time_length(dur, "day"), 2))
per <- lubridate::period(1, "month")
stopifnot(lubridate::is.period(per),
          identical(lubridate::`%m+%`(lubridate::ymd("2024-01-31"), per),
                    lubridate::ymd("2024-02-29")))
int <- lubridate::`%--%`(lubridate::ymd("2024-01-01"), lubridate::ymd("2024-02-01"))
stopifnot(lubridate::is.interval(int),
          identical(lubridate::int_length(int), 2678400),
          isTRUE(lubridate::`%within%`(lubridate::ymd("2024-01-15"), int)),
          identical(lubridate::as.duration(int), lubridate::duration(2678400)))
stopifnot(identical(lubridate::decimal_date(lubridate::ymd("2024-07-02", tz = "UTC")),
                    2024.5))

# Exported constants keep their classes and the lazy dataset is the
# historical play-by-play data frame.
stopifnot(inherits(lubridate::NA_Date_, "Date"), is.na(lubridate::NA_Date_),
          inherits(lubridate::NA_POSIXct_, "POSIXct"),
          is.na(lubridate::NA_POSIXct_),
          identical(lubridate::origin,
                    as.POSIXct("1970-01-01", tz = "UTC")))
lakers <- lubridate::lakers
stopifnot(is.data.frame(lakers), nrow(lakers) == 34624L,
          all(c("date", "opponent", "etype", "player", "points") %in%
                names(lakers)))

cat("lubridate exports, formals, lazy dataset, and date-time behavior verified.\n")
