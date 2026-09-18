# PR #69 (fixes #61): multi-model AIC() returns a data frame, so `$AIC`
# column access is legal and must stay quiet.
a <- AIC(1, 2)
b <- a$AIC
