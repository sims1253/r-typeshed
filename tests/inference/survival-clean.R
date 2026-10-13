# survival 0.0.2: optional formals without defaults stay omittable, and
# the arguments each formula interface forwards to model.frame resolve in
# the data mask (RY091/RY010 false positives under the generated draft).
library(survival)
d <- data.frame(time = c(5, 8, 12), status = c(1, 0, 1), age = c(60, 55, 70), id = 1:3)
a <- aareg(Surv(time, status) ~ age, d, weights = age, subset = age > 50, cluster = id)
r <- rttright(Surv(time, status) ~ 1, d, id = id)
y <- pyears(Surv(time, status) ~ 1, d, subset = age > 50)
k <- survcondense(Surv(time, status) ~ age, d, id = id)
p <- dsurvreg(1, 0)
s <- survreg(Surv(time, status) ~ age, d, NULL, age > 50, cluster = id)
f <- survfit.formula(Surv(time, status) ~ 1, d, id = id, cluster = id)
