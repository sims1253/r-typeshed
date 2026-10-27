# all_labels() captures only its filters: an unbound name passed to an
# eager knitr function must still warn RY010 beside the capturing call.
library(knitr)
labels <- all_labels(engine == "R")
knit_child(zz_unbound_child)
