# knitr's all_labels() captures its filters with match.call() and evaluates
# them against each chunk's options; all_rcpp_labels() forwards `...` to it.
# A chunk option name in a filter must not warn RY010.
library(knitr)
r_labels <- all_labels(engine == "R")
rcpp_labels <- all_rcpp_labels(echo)
