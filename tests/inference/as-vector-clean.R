# PR #67 (fixes #60): as.vector() with mode = "list" returns a list, so
# `$` on the result is legal and must stay quiet.
v <- as.vector(1L, mode = "list")
m <- v$missing
