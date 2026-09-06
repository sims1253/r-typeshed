# r-typeshed

`r-typeshed` provides curated R package stubs for the [ry](https://github.com/sims1253/ry) static type checker. Stubs describe function signatures, dataset types, non-standard evaluation (NSE), and S3 methods.

See the [schema reference](schema/SCHEMA.md) for the file format and
[contributing guide](CONTRIBUTING.md) to add or update stubs.

## Using the stubs

ry includes a snapshot of these stubs. To test a local checkout, add its
`stubs` directory to your project's `ry.toml`:

```toml
typeshed = ["../r-typeshed/stubs"]
```

Relative paths start at the directory containing `ry.toml`. Local stubs replace
embedded stubs for the same package. See [Versioning](#versioning) for consumer
compatibility.

## Contributing

The [contributing guide](CONTRIBUTING.md) covers package generation, local
checks, automated update drafts, and the generated base inventory. Generators
produce drafts; review their types and evaluation metadata before submitting
a pull request.

## Versioning

Tagged releases are immutable snapshots that ry vendors. Each stub's `version`
identifies its data revision; `schema_version` changes only when the format
has a breaking change.

Schema 2 requires a compatible ry loader. Update ry's parser, validator,
checker interpretation, and vendored snapshot together before using a schema-2
release.

CI and the draft workflow build the ry revision pinned in
[`.github/ry-consumer`](.github/ry-consumer). Use that revision for local
validation too; older releases can miss mixed-case stub paths. Update the pin
when changes need a newer loader. Schema validation and its regression
fixtures live in ry. The R audits here check declarations against installed
R packages.
