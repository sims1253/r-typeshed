# library(tidyverse) attaches forcats, which has no stub, so its exports
# stay resolvable as unknown names.
library(tidyverse)
f <- fct_rev(factor(c("a", "b")))
