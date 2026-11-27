# Partial stub (withr) acts as an open namespace so unstubbed exports like
# with_envvar() do not trigger RY010 while known injects still apply.
library(withr)
with_envvar(c(FOO = "1"), Sys.getenv("FOO"))
with_tempfile("tmp_file", {
  file.exists(tmp_file)
})
