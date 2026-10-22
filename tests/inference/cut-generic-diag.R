# Neighboring true-error control: cut() on a plain numeric vector still
# returns an integer vector, which rejects `$`.
x <- cut(c(1, 2, 3), 2)$lower
