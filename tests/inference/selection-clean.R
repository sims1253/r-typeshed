# Selections keep the first argument's mode and class but re-count its
# elements, so none of these conditions or sums claims the input's length.
x <- c(3, 1, 2)
if (head(x, 1) > 0) 1L
if (tail(x, 1) > 0) 1L
if (unique(c(5, 5)) > 1) 1L
if (setdiff(c(1, 2, 3), c(2, 3)) == 1) 1L
if (union(c(1, 1), 1) == 1) 1L
if (na.omit(c(1, NA)) == 1) 1L
y <- head(1:10, 3) + c(1, 2, 3)
b <- as.integer(head(c(1, 1e10), 1))
d <- as.integer(setdiff(c(1e10, 1), 1e10))
