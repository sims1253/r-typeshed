# box imports an export of a stubbed package. The gate runs with
# RY_NO_INSTALLED_LIBRARIES=1, so only the candidate dplyr stub decides that
# this file is clean: `inference_mutation_test.sh <ry> installed-library`
# plants a library whose dplyr exports only `select` and proves the gate
# ignores it.
box::use(dplyr[filter])
d <- data.frame(mpg = 1L)
filter(d, mpg > 0)
