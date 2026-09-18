# Dump fixtures: one binding per file so the inferred type string pins the
# candidate stub's fact. Run under an ry.toml pointing at the candidate
# stubs (dump-types has no --typeshed flag at the pin).
d <- dnorm(0, mean = c(0, 1))
