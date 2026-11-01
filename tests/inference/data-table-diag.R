# Neighboring true-error controls: an atomic vector's `[` is not a column
# mask, and a name outside any `[` is still unbound.
x <- c(1, 2)
x[a > 1]
print(a)
# The formals around a quoted `...` are evaluated: the table and
# `na.last` below are unbound.
data.table::setorder(missing_table, a)
data.table::frank(data.table::data.table(a = 1), a, na.last = missing_flag)
