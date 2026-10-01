# Security and resource boundaries

URI Template expansion is string construction, not destination validation. RFC 6570 permits `+` and `#` expansions to retain reserved characters; an untrusted value can therefore change the apparent path, query, or fragment. Use those operators only when their behavior is required, and validate the final URI with an application-specific policy before making requests. This library performs no DNS lookup, network request, filesystem access, or authority allowlist check.

`parse` validates a well-formed UTF-16 template and RFC literal/varspec grammar. The default limits are 65,536 UTF-16 code units, 1,024 expressions, and 4,096 variable specifications. `Template::expand` validates every binding and defaults to 4,096 bindings, 1,048,576 UTF-16 units per scalar/key/member, 4,096 items per composite, and 1,048,576 output characters. These are logical work limits, not a process RSS cap. Callers can set lower values for untrusted inputs.

The output limit is checked while pieces are collected and before returning a URI. One percent-encoded scalar or list member is still materialized temporarily; its size is bounded by the configured value limit. An error never returns partial output. The implementation is pure MoonBit; no global mutable state is used in the library.

The JSON bridge accepts strings, null, and one-level arrays/objects whose leaves are strings or null. Numeric and boolean values are rejected rather than coerced. JSON parsers may already have discarded duplicate object keys before building a `Json` tree; callers requiring duplicate-key rejection must enforce it at their text parsing boundary. Object keys are sorted for deterministic expansion.

Unicode normalization is the caller's responsibility. RFC 6570 recommends NFC for user-supplied text but does not mandate normalization of values already supplied by a service. The library percent-encodes the exact well-formed scalar sequence supplied. Error descriptions avoid embedding values, though variable names remain visible.
