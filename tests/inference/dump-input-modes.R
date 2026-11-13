# #125: sum, abs, max, and range follow the mode of their data
# arguments through an `input_mode` rule. The pre-rule `double_or_int`
# stubs read each of these as double, integer, or unknown. pmax() of
# logical data is logical or integer by argument count, so no claim.
sc <- sum(complex(real = 1, imaginary = 1))
ac <- abs(complex(real = 1, imaginary = 1))
mc <- max("a", "b")
rc <- range(c("a", "b"))
me <- max(integer(0))
pn <- pmax(c(TRUE, FALSE))
