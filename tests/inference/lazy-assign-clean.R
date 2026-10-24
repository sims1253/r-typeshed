# rlang's `%<~%` is delayedAssign(as_string(substitute(lhs)),
# substitute(rhs)): the left side is a captured name, never read, and the
# right side is a lazy promise evaluated on first access (sims1253/ry#706).
# Neither side may warn RY010 for a name with no binding in scope.
library(rlang)
zz_lazy_target %<~% zz_lazy_value
