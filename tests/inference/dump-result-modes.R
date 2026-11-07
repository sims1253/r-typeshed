# #124/#126: mean, sign, ave, sample, seq.int, and median no longer claim
# a mode that GNU R contradicts. Each binding was inferred integer (or
# double for the seq.int callback), while R returns double, mixed, or
# integer.
m <- mean(1:3)
s <- sign(1L)
a <- ave(1:3)
sm <- sample(10)
q <- lapply(c(1, 2), seq.int)
md <- median(1:4)
