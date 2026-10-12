# library(tidyverse) attaches purrr, so map_dbl's callback contract applies.
library(tidyverse)
xs <- map_dbl(1:3, function(x) paste("n", x))
