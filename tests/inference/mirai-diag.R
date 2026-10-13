library(mirai)
# `...` is evaluated in the caller through list(...): an unbound value must
# still warn RY010 while the quoted .expr beside it stays silent.
m <- mirai(a + 1, a = zz_missing_mirai_value)
