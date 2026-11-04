# #128: table(), proc.time(), ordered(), interaction(), and dist() carry
# their S3 classes; ts() and as.factor() are opaque because their class
# depends on the input (a matrix gives "mts", an ordered factor stays
# ordered).
t1 <- table(c("a", "b"))
pt <- proc.time()
o <- ordered(c("a", "b"))
i <- interaction(c("a", "b"), c("x", "y"))
d <- dist(matrix(1:4, 2))
s <- ts(1:10)
af <- as.factor(c("a", "b"))
