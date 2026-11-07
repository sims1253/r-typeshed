# #127: names() is NULL for a plain vector, so arithmetic on it gives
# numeric(0) in R. The old character-only return reported RY040 here.
ok <- names(1:3) + 1
# nrow() is opaque rather than integer-or-NULL: a NULL member would make
# the idiomatic non-empty test below report RY001 for a data frame.
d <- data.frame(a = 1)
if (nrow(d)) print(1)
