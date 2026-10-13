# mirai(), try_mirai(), and everywhere() capture .expr with substitute() and
# evaluate it on a daemon, so names supplied through `...` must not warn RY010.
library(mirai)
m <- mirai(a + b, a = 1, b = 2)
t <- try_mirai(scale * value, scale = 2, value = 21)
e <- everywhere(library(pkg_on_daemon_xyz))
