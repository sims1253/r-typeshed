# rlang::caller_arg() captures its argument's expression with substitute()
# (sims1253/ry#688), so the argument is never evaluated and a name with no
# binding in scope must not warn RY010.
label <- function() rlang::caller_arg(zz_never_evaluated)
