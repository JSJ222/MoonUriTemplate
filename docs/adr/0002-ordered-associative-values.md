# Preserve insertion order in associative values

Associative expansion follows the caller's ordered key-value sequence, rather than an unordered map. URI Template expansions can appear in signatures, cache keys, and test fixtures, where unstable output is surprising and costly to change. Callers can sort the sequence explicitly when a canonical key order is required.
