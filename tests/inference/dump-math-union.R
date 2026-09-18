# PR #73: complex-capable math returns a double/complex union, so `exp`
# on plain input keeps an inferred union result.
e <- exp(1)
