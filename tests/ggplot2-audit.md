# ggplot2 inventory corpus comparison

Verified on 2026-09-07 with ggplot2 4.0.3 and R 4.6.1. The catalog contains
498 exported functions, 145 exported non-function values, and 11 lazy datasets.
All parameters are inference-only. All returns and new value types are unknown;
the existing `.pt` declaration remains a non-missing double scalar.

The same ry binary (commit `d5414ff`) checked the same 500 package checkouts in
three runs. Installed-library discovery was disabled with
`RY_NO_INSTALLED_LIBRARIES=1`; `RAYON_NUM_THREADS=1` was also fixed. Only the
ggplot2 directory was passed to `--typeshed`, so unrelated upstream stubs could
not affect the comparison. Diagnostics were compared by all JSON fields.

| Catalog | Total diagnostics | RY010 | RY070 |
| --- | ---: | ---: | ---: |
| Embedded baseline | 2712 | 1367 | 112 |
| Four-entry ggplot2 catalog (`edafabd`) | 2694 | 1351 | 110 |
| Complete ggplot2 inventory | 2475 | 1135 | 107 |

The complete inventory removes 237 diagnostics from the embedded baseline and
adds none. Compared with the four-entry catalog, it removes another 219 and adds
none. The largest baseline reductions are ggforce (65), ggpubr (55), and ggraph
(42). Improvements also occur in bayesplot, GGally, plotly, factoextra, ggrepel,
ggtext, ggmap, cowplot, and units.

The first export-only candidate introduced one warning for `diamonds` in renv.
R exposes this lazy dataset through `ggplot2::diamonds`, although it is absent
from `getNamespaceExports()`. Including the verified lazy-dataset inventory
removes that warning; the final run has no new diagnostics.

Replay each package with:

```sh
RY_NO_INSTALLED_LIBRARIES=1 RAYON_NUM_THREADS=1 ry check "$package_path" \
  --typeshed stubs/ggplot2 --output-format json
```

The local corpus manifest records package checkout commits. Its SHA-256 is
`88f205a88349f03cc92c758ed18a0c431740b374f75e06240723d586322dcd3d`.
The corpus and raw outputs are external measurement artifacts; runtime export,
formal, value, and capture checks live in `tests/ggplot2.R` and run in CI.
