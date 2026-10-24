# env_bind_lazy() evaluates `.env`, so an unbound name there must still warn
# RY010 beside the capturing `%<~%` below.
library(rlang)
zz_lazy_target %<~% 1
env_bind_lazy(zz_unbound_env, value = 1)
