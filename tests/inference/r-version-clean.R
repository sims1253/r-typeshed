# PR #71 (fixes #62), checker-visible half: the lowercase `R.version`
# phantom is gone from `functions`, while `R.Version()` keeps its
# list return — so `$major` on the call result is legal and stays quiet.
# (Bare `R.version()` calls are silent under both old and new stubs, so the
# phantom's absence is pinned by the audit in tests/audits.R, not here.)
s <- R.Version()$major
