# Neighboring true-error controls: date() still returns a plain string,
# and unclassing Sys.time() still leaves a double.
s <- date()$x
n <- as.numeric(Sys.time()) + "a"
