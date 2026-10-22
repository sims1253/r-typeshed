# Neighboring true-error control: the default quantile still returns a
# double vector, which rejects `$`.
x <- quantile(c(1, 2, 3))$quantile
