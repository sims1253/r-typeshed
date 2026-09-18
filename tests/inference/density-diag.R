# Neighboring true-error control for the density fixes: c() keeps its
# exact-length inference, so a length-2 condition must still warn RY002.
y <- c(FALSE, TRUE)
if (y) 1L
