# Control: NULL + "x" errors like character + "x", so every member of
# names()'s character/NULL union still mismatches and RY040 must fire.
bad <- names(c(a = 1)) + "x"
