# r-typeshed

`r-typeshed` is a curated typeshed for the R ecosystem. It provides package function signatures, dataset types, and S3 method metadata consumed by the [ry](https://github.com/posit-dev/ry) static type checker.

See [schema/SCHEMA.md](schema/SCHEMA.md) for the file format.

## Adding a package

1. Run `Rscript scripts/gen_typeshed.R <package>` to generate a draft.
2. Hand-curate return types, evaluation modes, aliases, datasets, and methods.
3. Run `Rscript scripts/audit_typeshed.R` to check names against installed packages.
4. Run `ry typeshed validate stubs/`.
5. Open a pull request containing `stubs/<package>/<package>.json`.

The generator is a starting point, not type inference. Every draft requires review.

## Versioning

`schema_version` is bumped only for breaking schema changes. Tagged repository releases are immutable snapshots that ry vendors. Individual stub `version` fields describe their data revision.

ry provides R static analysis. It shares the broader developer-tooling ecosystem with air, an R formatter, and jarl, an R linter; those tools do not consume these signatures directly.
