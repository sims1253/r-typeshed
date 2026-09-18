# Member-wise mismatch still fires through the union: a union result in
# character arithmetic must error RY040.
e <- exp(1)
bad <- e + "x"
