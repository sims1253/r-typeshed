# Known-safe calls that must stay quiet: scalar arithmetic, string
# building, and string measurement claim nothing controversial.
x <- 1L + 2L
y <- paste0("a", "b")
z <- nchar("hello")
