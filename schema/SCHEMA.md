# Stub schema

Each JSON file describes one R package. Validate stubs with `ry typeshed validate`; the serde definitions and loader in ry's `crates/ry-typeshed/src/lib.rs` are the normative machine-readable schema. This document is the single documentation source for the format.

The required header fields are `schema_version`, `package`, and `version`. `functions` is also required; `globals`, `datasets`, and `s3_methods` are optional.

## Functions

Function names map to signatures. A signature requires `params`, an ordered array of parameters, and `return`. A parameter may be a bare name string or an object with a required `name` and optional `type`, `required`, and `default` fields. Bare strings remain valid and mean an untyped, non-required parameter. `type` uses the same R type object as return values; absent types are not checked. `required` defaults to false and means calls must bind the parameter. `default` is informational and records whether the formal has a default. The variadic `...` parameter may be a string or `{"name": "..."}`, but cannot be typed or required. Optional signature fields are `aliases`, `eval`, `schema_effect`, `higher_order`, and `source_relative_path_arg`, a zero-based literal argument containing a path relative to the current source file.

Legacy all-string `params` arrays remain inference-only because older stubs may contain abbreviated formal lists. To opt a signature into unknown-argument checking, add `required`, `default`, or `type` metadata to at least one parameter and list the complete public formal sequence, including `...` and formals after it. The checker then uses the list for exact, partial, and positional argument matching.

`return` is either the bare string `"arg0"` or `"concat_of_args"`, or an R type object. An R type requires `mode` and `length`; it may also contain `na`, a descriptive `note`, an S3 `class` vector, and recursive named `columns`. `note` is documentation metadata retained from the source corpus and ignored by current consumers.

The supported modes are `arg0`, `arg2`, `character`, `complex`, `double`, `double_or_int`, `function`, `integer`, `list`, `logical`, `null`, `opaque`, `raw`, `union`, and `yes_or_no`. Concrete modes mirror R values. `opaque` is unknown. The remaining values are checker-resolved symbolic modes derived from arguments or call behavior. A `union` type also requires a non-empty `members` array of concrete mode names; for example `{"mode": "union", "length": "unknown", "members": ["logical", "integer", "double"]}` describes numeric-like values accepted through R's ordinary coercion ladder.

Lengths may be a decimal string from the curated vocabulary accepted by `ry typeshed validate`. Symbolic lengths are `arg0`, `arg1`, `arg2`, `longest_arg`, `n_args`, `test`, `unknown`, and `x_times`; the checker resolves these from call arguments or operation semantics.

The `eval` map assigns parameter names one of `normal`, `quoted_symbol`, `quoted_expression`, `data_mask`, or `tidy_select`. These describe R's non-standard evaluation behavior.

`schema_effect` describes how a data-aware function computes its result schema after evaluating arguments. `preserve` returns the first argument unchanged; `add_named_args` adds named arguments as columns; `select` keeps selected columns; `aggregate` creates a fresh data frame from named arguments; and `expression_value` returns the second argument's inferred type. The `join` and `pivot` values dispatch to the checker's deliberately bespoke join-union and pivot implementations while keeping the triggering function names in stub data.

`higher_order` declares callback invocation and result semantics. `callback_param` and zero-based `callback_position` locate the callback. `callback_args` may contain `element_of_arg0`, `element_of_arg1`, `unknown`, or `accumulator_and_element`; `elements_after_callback` represents variadic `Map`-style calls. Result kinds are `list_of_callback_return`, `vector_of`, `same_as_arg0`, `callback_return`, `first_arg`, `simplify`, `fun_value_template`, and `callback_identity`. A result may additionally name its vector `mode`, a `length_arg`, a returned `source_arg`, the `template_position`, whether its length becomes unknown, and whether a list result retains callback element schema. These optional properties preserve package-specific call shapes without encoding function names in the checker.

## Datasets and S3 methods

`datasets` maps dataset names to R type objects. `s3_methods` is an array whose entries add required `generic` and `class` strings to all function signature fields. Function and R type objects are closed: unrecognized fields are rejected.

## Global checker semantics

The optional top-level `globals` object contains package data used while resolving ordinary R names and S3 methods. `ambient` lists names available without a local binding, `s3_generics` lists generic prefixes recognized when splitting `<generic>.<class>` method names, and `s3_split_denylist` lists dotted names that must never be split as S3 methods. Each field is an optional array of strings and defaults to empty.

These values normally belong to the `base` stub. A user-supplied `base` stub replaces the embedded base stub wholesale, so it also controls all three global tables.

`schema_version` changes only for incompatible format changes. Package `version` describes the stub data version.
