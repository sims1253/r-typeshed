# PR #70 (fixes #64): dnorm() recycles across value arguments, so the
# result length is unknown and the checker claims nothing about it.
d <- dnorm(0, mean = c(0, 1))
e <- dpois(0, lambda = c(1, 2))
