# The stale scalar-double AIC contract is gone, but `$` on an atomic
# vector is still invalid: this must error RY061.
m <- 1L$missing
