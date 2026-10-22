# Third-party material

## API contract workspace (0.3.0)

The `contracts` package depends on [moonbitstack/moonschema 0.2.0](https://github.com/moonbitstack/moonschema), licensed Apache-2.0. It reuses the published `Schema::new`, `valid`, and `faults` interpreter rather than claiming to reimplement JSON Schema. Dependency source is not vendored; its existing copyright and license remain with its authors. The workspace, importer, locking/dependency/update/gate implementation and original examples are JSJ222 project contributions developed with AI assistance.

The optional differential tool uses [python-jsonschema 4.26.0](https://github.com/python-jsonschema/jsonschema), MIT, as an independently executed development-time oracle. It is not a runtime dependency and no source is copied. The 351 combinations emitted by `tools/contract_oracle` are original synthetic fixtures. They are not the official JSON Schema suite, upstream moonschema test results, full OpenAPI conformance or production traffic.

[OpenAPI 3.1](https://spec.openapis.org/oas/v3.1.1.html) and [JSON Schema 2020-12](https://json-schema.org/draft/2020-12/json-schema-validation) are behavioral references, not redistributed specification text. Other MoonBit contract libraries listed in the documentation are comparison references only, not copied implementations. No uniqueness or exhaustive ecosystem coverage claim is made.

The optional `tools/windows` argv adapter is reused from the workspace's
MoonTUF compatibility utility (Apache-2.0), authored with AI assistance. It only
launches official MoonBit tools with normalized DOS paths; it contains no URI
template implementation. New runtime contract/session code is original and
was also developed with AI assistance.

The runtime MoonBit implementation is original code written for this project, following RFC 6570. No other URI Template implementation source was copied.

The JSON conformance fixtures in `testdata/uritemplate-test/` come from [uri-templates/uritemplate-test](https://github.com/uri-templates/uritemplate-test), pinned to commit `4171dac22aa67fc710b3f6df308a50bd08552986`. Upstream copyright and Apache-2.0 terms are retained in `testdata/uritemplate-test/LICENSE`. The files are unmodified; `tools/generate_conformance.py` converts their data to portable MoonBit tests. The generated test file is derived from those fixtures and is covered by the same attribution.

The [RFC 6570 specification](https://www.rfc-editor.org/rfc/rfc6570) is used as a behavioral reference. The project does not redistribute specification text.
