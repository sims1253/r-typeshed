# Higher-order control: vapply() templates its result from FUN.VALUE, so
# a double result used in character arithmetic must still error RY040.
v <- vapply(c(1, 2, 3), function(x) x * 2, numeric(1))
bad <- v + "x"
