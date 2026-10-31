# Neighboring true-error controls: an atomic vector's `[` is not a column
# mask, and a name outside any `[` is still unbound.
x <- c(1, 2)
x[a > 1]
print(a)
