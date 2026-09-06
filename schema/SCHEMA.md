# Stub schema

Each JSON file describes one R package. Validate stubs with `ry typeshed validate`; the serde definitions and loader in ry's `crates/ry-typeshed/src/lib.rs` are the normative machine-readable schema. This document is the single documentation source for the format.

The required header fields are `schema_version`, `package`, and `version`. `functions` is also required; `globals`, `datasets`, and `s3_methods` are optional. Schema version 2 extends version 1 with declarative predicate, assertion, conditional scope, and return-length semantics. Version 2 is a justified schema bump: ry versions that only support version 1 must reject it rather than silently ignore semantic fields.

## Functions

Function names map to signatures. A signature requires `params`, an ordered array of parameters, and `return`. A parameter may be a bare name string or an object with a required `name` and optional `type`, `required`, and `default` fields. Bare strings remain valid and mean an untyped, non-required parameter. `type` uses the same R type object as return values; absent types are not checked. `required` defaults to false and means calls must bind the parameter. `default` is informational and records whether the formal has a default. The variadic `...` parameter may be a string or `{"name": "..."}`, but cannot be typed or required. Optional signature fields are `aliases`, `eval`, `no_return`, `schema_effect`, `scope_effect`, `conditional_scope_effect`, `predicate`, `assertion`, `return_length`, `higher_order`, and `source_relative_path_arg`, a zero-based literal argument containing a path relative to the current source file. `no_return` defaults to false and marks a function that never returns to its caller.

Legacy all-string `params` arrays remain inference-only because older stubs may contain abbreviated formal lists. To opt a signature into unknown-argument checking, add `required`, `default`, or `type` metadata to at least one parameter and list the complete public formal sequence, including `...` and formals after it. The checker then uses the list for exact, partial, and positional argument matching.

`return` is either the bare string `"arg0"` or `"concat_of_args"`, or an R type object. An R type requires `mode` and `length`; it may also contain `na`, a descriptive `note`, an S3 `class` vector, and recursive named `columns`. `note` is documentation metadata retained from the source corpus and ignored by current consumers.

The supported modes are `arg0`, `arg2`, `character`, `complex`, `double`, `double_or_int`, `function`, `integer`, `list`, `logical`, `null`, `opaque`, `raw`, `union`, and `yes_or_no`. Concrete modes mirror R values. `opaque` is unknown. The remaining values are checker-resolved symbolic modes derived from arguments or call behavior. A `union` type also requires a non-empty `members` array of concrete mode names; for example `{"mode": "union", "length": "unknown", "members": ["logical", "integer", "double"]}` describes numeric-like values accepted through R's ordinary coercion ladder.

Lengths may be a decimal string from the curated vocabulary accepted by `ry typeshed validate`. Symbolic lengths are `arg0`, `arg1`, `arg2`, `longest_arg`, `n_args`, `test`, and `unknown`; the checker resolves these from call arguments or operation semantics.

`return_length` records a named, reusable exact-length rule. It is not an interval or upper-bound language: consumers whose length domain cannot retain a fact must yield `unknown`, never turn a bound into an exact length. `{"kind": "zero_if_any_param_zero", "params": ["x", "y"]}` requires at least two individually unique formal names and returns exact zero when any listed, bound parameter is known to have exact length zero; in every other case it yields unknown. This captures the only exact length fact supplied by a set-operation bound such as `intersect()` without falsely claiming that its result has the shorter input's length.

`{"kind": "recycled_values", ...}` describes vector recycling without treating controls as values. `value_params` must not be empty. It and `control_params` contain disjoint, individually unique formal-parameter names, resolved with R's normal exact, partial, and positional argument matching. A `...` value parameter denotes every argument captured by that formal; it does not include arguments bound to a named control. All non-`...` value parameters and every control must be explicit, so a consumer can determine the value set without relying on an argument's source position. `collapse.param` and `recycle0.param` must each be a member of `control_params`. `all_values_zero: "zero"` preserves the all-empty result, `collapse` requires `when: "non_null"` and `length: "1"`, and `recycle0` requires `when: "true"` and `any_value_zero: "zero"`. Each control rejects fields belonging to the other. This models the real `paste`/`paste0` contract, including `collapse` and `recycle0`, without special-casing function names.

The `eval` map assigns parameter names one of `normal`, `quoted_symbol`, `quoted_expression`, `captures_promise`, `data_mask`, or `tidy_select`. These describe R's non-standard evaluation behavior. `captures_promise` records a promise captured without evaluation, including a variadic `...` promise capture.

`schema_effect` describes how a data-aware function computes its result schema after evaluating arguments. `preserve` returns the first argument unchanged; `add_named_args` adds named arguments as columns; `select` keeps selected columns; `aggregate` creates a fresh data frame from named arguments; and `expression_value` returns the second argument's inferred type. The `join` and `pivot` values dispatch to the checker's deliberately bespoke join-union and pivot implementations while keeping the triggering function names in stub data.

`scope_effect` describes changes to name resolution caused by a call and is independent of `schema_effect`. Its supported value, `unknown_bindings`, means the call can introduce bindings whose names cannot be determined statically; later unresolved names in the same scope are therefore treated as uncertain. `conditional_scope_effect` makes that effect precise when a loader's target scope depends on the call: it has `effect: "unknown_bindings"`, `current_scope_when: {"param": "local", "equals": true}`, and `default_current_scope: "top_level"`. `current_scope_when.equals` must be `true` in the current schema. `base::source` uses this form: `local = TRUE` affects the caller frame; its default `.GlobalEnv` affects the current scope only at top level.

`predicate` declares that a scalar logical result tests `subject_param` against an R type `target`, allowing normal branch narrowing from ordinary call resolution rather than a name table. `subject_param` is a formal name, not a call-argument index: consumers must first bind actual arguments under R's exact, partial, and positional matching rules, and narrow only when the bound actual is a simple variable reference. `rlang::is_null` is the canonical null-predicate example.

`assertion` declares an assertion-style helper that, when it returns normally, proves `target` for `subject_param`. `subject_param`, `allow_null_param`, and `allow_na_param` are formal names with the same R argument-binding requirement as predicates; a control weakens the fact only when its actual has been bound to that formal. To avoid claiming semantics for conventional helper names, assertions are accepted only with real provenance: `provenance` must be `{"kind": "standalone_types_check", "fingerprint_params": ["arg", "call"]}` and those parameters must exist in the signature. This is intentionally restricted to rlang's standalone `check_*` implementation shape; generic assertion metadata is not inferred from a name.

`higher_order` declares callback invocation and result semantics. `callback_param` and zero-based `callback_position` must identify the same formal parameter in `params`. `callback_args` may contain `element_of_arg0`, `element_of_arg1`, `unknown`, or `accumulator_and_element`; `elements_after_callback` represents variadic `Map`-style calls. Result kinds are `list_of_callback_return`, `vector_of`, `same_as_arg0`, `callback_return`, `first_arg`, `simplify`, `fun_value_template`, and `callback_identity`. A result may additionally name its vector `mode`, a `length_arg`, a returned `source_arg`, the `template_position`, whether its length becomes unknown, and whether a list result retains callback element schema. These optional properties preserve package-specific call shapes without encoding function names in the checker.

`injects` declares bindings visible while selected arguments are inferred. It is an array of objects with a required `into` array of parameter names. `strings_from` names source parameters whose string literals (including literals inside `c(...)`) become opaque bindings, while `names` lists fixed opaque bindings. Named call arguments are matched first and unnamed arguments fall back to the declared parameter order. Fixed names apply to function literals nested anywhere inside an `into` argument. For example:

```json
"injects": [
  {"into": ["code"], "strings_from": ["new"]},
  {"into": ["public", "private", "active"], "names": ["self", "private", "super"]}
]
```

## Datasets and S3 methods

`datasets` maps typed package values to R type objects. Despite the legacy
field name, entries may be exported constants as well as conventional package
datasets; consumers resolve them as non-callable values under ordinary
namespace/import provenance. In the `base` stub the entries are inventoried
from the default search path: some name base's own namespace constants
(`letters`, `pi`), while the conventional datasets (`mtcars`, `state.name`)
are provided by the attached `datasets` package rather than by base itself.
`s3_methods` is an array whose entries add
required `generic` and `class` strings to all function signature fields.
Registrations count even when their method function is unexported: the base
inventory generator harvests `S3methods` from installed base/recommended
namespaces and emits conservative signatures for them. Function and R type
objects are closed: unrecognized fields are rejected.

## Global checker semantics

The optional top-level `globals` object contains package data used while resolving ordinary R names and S3 methods. `ambient` lists non-function names available without a local binding, `ambient_functions` lists untyped functions available without a local binding, `s3_generics` lists generic prefixes recognized when splitting `<generic>.<class>` method names, and `s3_split_denylist` lists dotted names that must never be split as S3 methods. Each field is an optional array of strings and defaults to empty.

These values normally belong to the `base` stub. A user-supplied `base` stub replaces the embedded base stub wholesale, so it also controls all four global tables.

Run `Rscript --vanilla scripts/gen_standard_globals.R` to refresh the base
stub's ambient globals and mechanically inventoried base/recommended datasets.
Generated datasets are unioned with the existing map, and existing curated
entries are never replaced. Pass `--check` to verify that both inventories are
current without writing the file.

`schema_version` changes only for incompatible format changes. Package `version` describes the stub data version.

## Literal sizes, typed callbacks, and injection

`return_length: {"kind": "param_value", "param": "length", "default_length": 0}` uses a numeric parameter's value as the result length. Numeric sizes truncate towards zero. Dynamic or invalid sizes remain unknown. The named parameter must exist. This differs from `return.length: "arg0"`, which copies the length of the argument itself.

`higher_order.callback_return_mode` optionally requires each callback result to be one logical, integer, double, or character value. It is independent of the result vector's length and mode. Consumers must allow potentially valid numeric conversions and avoid checking callbacks for known-empty inputs. `callback_args: ["elements_of_arg0"]` supplies one element from each component of the first argument, as in `pmap()`.

`injection` maps formal names to `"full"` (tidy-evaluation `!!` and `!!!`) or `"splice"` (dynamic dots accepting `!!!` for values and `!!` on the left of `:=`). For example, `rlang::list2()` declares `{"...": "splice"}`. It uses ordinary argument matching, including `...`. Data masking alone does not imply injection: base `with()` evaluates `!!x` as two negations. Known ordinary arguments retain R negation semantics. When a callable has no available evaluation contract, a consumer must allow for argument capture rather than assume repeated negation executes.
