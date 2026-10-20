# Runtime contracts and incremental links

Compatibility note: mutable internal fields of `Template`, `TemplateCatalog`
and `BoundTemplate` are now explicitly private. Direct field access must migrate
to existing methods such as `source()`, `variables()`, `names()`, `get()` and
`fixed_names()`. Ordinary public method signatures/expansion behavior remain.
MoonBit `pub struct` alone is readonly, not opaque: reading an array/Map field
would still allow mutation of its contents. New contract/session internals are
also explicitly private. See [MoonBit access control](https://docs.moonbitlang.com/en/latest/language/packages.html).

These opt-in APIs extend forward RFC 6570 expansion. They do not add reverse
matching, general URI parsing, HTTP requests or an OpenAPI/JSON Schema reader.

## Runtime parameter contracts

`Template::with_contract(rules, reject_unused=true)` captures `BindingRule`
declarations: variable name, `TextValue`/`ListValue`/`AssociationValue`, required
flag. Dense and sparse composites share a shape. Unspecified variables remain
optional. Compilation rejects duplicate/unknown rules and composite rules for
variables with prefix modifiers.

`ContractTemplate::validate` checks limits, duplicates, unused names, required
values, shapes and prefix constraints without rendering. `expand` also enforces
the output budget. Errors contain names/expected shapes, never supplied values.
Required follows [RFC 6570](https://www.rfc-editor.org/rfc/rfc6570) defined-value
semantics: an empty scalar is defined; empty composites and sparse composites
with no defined members are not. Existing `Template::expand` is unchanged.
An explicitly wrong-shaped optional binding is rejected even if it would render
no text. This is not numeric validation, URL destination safety or full JSON
Schema. Run `moon run examples/contracts --target wasm-gc`: a required user ID
and optional field list model SDK, MCP and service-link arguments.

## Incremental link snapshots

`TemplateCatalog::start_session(bindings)` constructs a reverse dependency
index, copies composite inputs and expands one shared environment. Unknown
bindings are rejected; absent variables use RFC omission. The complete initial
snapshot is measured before allocating URI outputs.

`LinkSession::update([SetBinding(name,value), RemoveBinding(name), ...])` returns
a new `LinkUpdate`; failure leaves the old session intact. Each name may appear
once in a patch. Identical values and removing absent bindings cause no work.
Every affected endpoint is measured/rendered once even when multiple variables
reach it. `recomputed()` counts affected endpoints; `changes()` returns actual
URI changes in catalog order. Prefix-equivalent values may yield recomputation
with no reported change. Getters return array copies. Keeping old snapshots
retains their captured values/strings; release snapshots no longer needed.

Default budgets: 4,096 bindings, 1,048,576 UTF-16 units per value/per URI,
4,096 items per composite and 16,777,216 total output units. A patch has a hard
maximum of 4,096 changes. All values are checked; the cumulative output budget
includes unchanged links. These are component limits, not a total input-memory
budget. Empty catalogs/patches are valid. Sparse `None` is distinct from removing
an entire binding.

Run `moon run examples/incremental_links --target wasm-gc`: a query update changes
one search link while an MCP resource and health link remain cached. Oversized
updates fail without replacing the valid snapshot. The same mechanism serves
live API consoles, tenant SDK link collections and hypermedia navigation when
filters, cursors or resource IDs change.

## Complexity and tradeoffs

N endpoints, R endpoint-variable edges, B bindings, P patch entries, D affected
edges and C affected-template input/output work: expected hash lookup is O(1),
index construction O(R), patch work O(B+N+P+D+C), plus value comparison/copy work.
Updates copy B binding references and N URI references and scan catalog order;
they do not promise O(affected endpoints) total time. Measurement still allocates
temporary encoded input buffers. State retains O(R+B+N) references plus captured
value/output content; staging adds changed composites/new URI content.

Compared with full regeneration, encoding/rendering is limited to affected
endpoints. A 200-endpoint test proves one dependency causes one recomputation.
When most endpoints change, full expansion may be simpler and avoids persistent
state overhead. No throughput speedup is claimed. Contract validation adds
O(B+rules+prefix variables+input content) before expansion; prefix information is
captured once. Expansion validates input again, trading a linear pass for reuse
of the existing checked expansion engine.
