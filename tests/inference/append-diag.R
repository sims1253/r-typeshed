# Neighboring true-error control for the append fix: c() keeps its exact
# concat_of_args inference, so a length-2 condition must still warn RY002.
# (append() itself is opaque now, so no `if (append(...))` spelling can
# serve as a condition-length control.)
y <- c(FALSE, TRUE)
if (y) 1L
