# #127: names(), dim(), nrow(), colnames(), and dimnames() return NULL
# for a plain vector, so each binding admits NULL.
nm <- names(1:3)
d <- dim(1:3)
r <- nrow(1:3)
cn <- colnames(1:3)
dn <- dimnames(1:3)
