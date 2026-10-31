# data.table's constructors return data.tables, so `[` scopes bare names
# to the table's columns: `a` and `b` below are columns, not unbound
# variables. Before the constructors were typed, each `a` was RY010.
d1 <- data.table::data.table(a = 1:3)
d1[a > 1]
d2 <- data.table::as.data.table(list(a = 1:3))
d2[a > 1]
d3 <- data.table::rbindlist(list(list(a = 1)))
d3[a > 1]
d4 <- data.table::CJ(a = 1:2, b = 3:4)
d4[a > b]
d5 <- data.table::setDT(list(a = 1:3))
d5[a > 1]
