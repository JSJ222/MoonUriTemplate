# Third-party material

The runtime MoonBit implementation is original code written for this project, following RFC 6570. No other URI Template implementation source was copied.

The JSON conformance fixtures in `testdata/uritemplate-test/` come from [uri-templates/uritemplate-test](https://github.com/uri-templates/uritemplate-test), pinned to commit `4171dac22aa67fc710b3f6df308a50bd08552986`. Upstream copyright and Apache-2.0 terms are retained in `testdata/uritemplate-test/LICENSE`. The files are unmodified; `tools/generate_conformance.py` converts their data to portable MoonBit tests. The generated test file is derived from those fixtures and is covered by the same attribution.

The [RFC 6570 specification](https://www.rfc-editor.org/rfc/rfc6570) is used as a behavioral reference. The project does not redistribute specification text.
