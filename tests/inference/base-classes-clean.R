# #128: ordered() returns class c("ordered", "factor"), so comparing it
# with a level is valid through Ops.ordered. The class-less stub
# reported RY033 here.
o <- ordered(c("a", "b"))
lo <- o < "b"
# proc.time() has class "proc_time", so the else branch never runs. The
# class-less stub reported RY061 for its `$`.
pt <- proc.time()
el <- if (inherits(pt, "proc_time")) pt[["elapsed"]] else pt$elapsed
