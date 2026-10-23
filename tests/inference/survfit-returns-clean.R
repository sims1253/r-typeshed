# survfit() and survfit.formula() return opaque values: every fit inherits
# "survfit", but multi-state and Cox curves add "survfitms"/"survfitcox",
# and a class-less list made quantile(fit) the default double quantile, so
# `$` on it reported RY061 (sims1253/ry#709).
library(survival)
d <- data.frame(time = c(5, 8, 12), status = c(1, 0, 1), arm = c("a", "b", "a"))
q <- quantile(survfit(Surv(time, status) ~ arm, data = d))
med <- q$quantile[, "50"]
lower <- q$lower[, "50"]
qf <- quantile(survfit.formula(Surv(time, status) ~ 1, d))
upper <- qf$upper
