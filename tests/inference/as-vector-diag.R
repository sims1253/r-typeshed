# Neighboring true-error control for as.vector: `$` on a plain atomic
# vector is still invalid and must error RY061.
m <- 1L$missing
