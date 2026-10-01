# Architecture and complexity

`parse.mbt` scans UTF-16 units once, validates literal/varspec grammar, and stores expression and variable spans. A hash map records first-seen variable names, so parsing takes O(T) expected time and O(T) AST space for template length T. The public offsets are UTF-16 code-unit offsets, matching MoonBit `String` indexing. A complete percent triplet in a variable name remains part of that name; it is not decoded.

`encoding.mbt` converts selected values to UTF-8 bytes and percent-encodes disallowed octets. Reserved/fragment operators retain RFC reserved characters and valid existing triplets. Prefix scanning counts Unicode scalar values and groups valid percent-encoded UTF-8 sequences. This avoids splitting surrogate pairs or a pre-encoded character at a prefix boundary.

`expand.mbt` builds a per-call binding map and renders each compiled segment. Missing bindings and empty composites contribute no text; empty strings remain defined. Each output piece is checked against the remaining budget before joining. With template length T, B bindings, total inspected value length V, and output length O, the expected time is O(T + B + V + O), excluding repeated output requested by repeated variable references. Space is O(T + B + O + M), where M is the largest encoded member temporarily materialized. The configured limits bound each component; they do not imply a hard process memory ceiling.

`analysis.mbt` derives source-aware expression and variable occurrence metadata for tools. `binding_report.mbt` compares a compiled template with caller bindings without exposing values. `json_bridge.mbt` sorts JSON object keys before constructing ordered association values. None of these paths access the network, filesystem, clock, or global mutable state.
