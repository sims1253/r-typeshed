# Neighboring true-error controls: a plain list still rejects arithmetic,
# and gc()'s double matrix still rejects character arithmetic.
x <- list(1, 2)[1] + 1
y <- gc() + "a"
