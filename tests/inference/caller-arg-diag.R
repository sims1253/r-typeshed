# rlang::caller_env() evaluates its `n` argument, so an unbound name there
# must still warn RY010 beside the capturing caller_arg().
frame <- function() rlang::caller_env(zz_unbound_frame_count)
