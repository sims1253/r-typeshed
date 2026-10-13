# Controls: survcondense really requires id ("id is required"); only
# model.frame arguments are masked, so a column passed to aareg's nmin is
# not; positionally, survreg's 7th formal is init (not cluster) and
# survfit's 6th is stype (not id), neither of which is masked.
library(survival)
d <- data.frame(time = c(5, 8, 12), status = c(1, 0, 1), age = c(60, 55, 70), id = 1:3)
k <- survcondense(Surv(time, status) ~ age, d)
a <- aareg(Surv(time, status) ~ age, d, nmin = age)
s <- survreg(Surv(time, status) ~ age, d, NULL, NULL, NULL, "weibull", age)
f <- survfit(Surv(time, status) ~ 1, d, NULL, NULL, NULL, id)
