# Control: the "table" class adds no arithmetic with character, so
# table + "x" still errors in R and RY040 must fire.
t1 <- table(c("a", "b"))
bad <- t1 + "x"
