# data.table(), SJ(), rbindlist(), and CJ() return data.tables, so `[`
# scopes bare names to the table's columns: `a` and `b` below are
# columns, not unbound variables. Before the constructors were typed, each `a` was RY010.
d1 <- data.table::data.table(a = 1:3)
d1[a > 1]
d2 <- data.table::SJ(a = 1:3)
d2[a > 1]
d3 <- data.table::rbindlist(list(list(a = 1)))
d3[a > 1]
d4 <- data.table::CJ(a = 1:2, b = 3:4)
d4[a > b]
# setorder(), frank(), setkey(), and setindex() capture their column
# names unevaluated, so `a` needs no binding here either.
data.table::setorder(d1, -a)
r <- data.table::frank(d1, a)
data.table::setkey(d1, a)
data.table::setindex(d1, a)
# rollup(), cube(), and groupingsets() evaluate `j` in the table's columns,
# so `a` in `sum(a)` needs no binding either.
r1 <- data.table::rollup(d1, j = sum(a), by = "a")
r2 <- data.table::cube(d1, sum(a), by = "a")
r3 <- data.table::groupingsets(d1, j = sum(a), by = "a", sets = list("a"))
