# Control: NULL + "x" errors like integer + "x", so every member of
# dim()'s integer/NULL union still mismatches and RY040 must fire.
bad <- dim(matrix(1:4, 2)) + "x"
