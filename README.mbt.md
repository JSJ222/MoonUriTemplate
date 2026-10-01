# MoonURITemplate

Pure MoonBit RFC 6570 Level 4 URI Template parser and expander for wasm, wasm-gc, JavaScript, and native targets.

Compile a template once, then expand it with typed scalar, list, or ordered associative values. The library supports all eight defined operators, prefix and explode modifiers, UTF-8 percent encoding, sparse composites, bounded processing, source-aware analysis, binding preflight, and a conservative JSON bridge.

Reusable catalogs, partial bindings, batch rendering, source-to-output spans, variable profiles, and opt-in template policies support SDK generators and hypermedia services. Every API returns typed errors; network destination validation remains the caller's responsibility.

`Template::measure` computes the exact expanded length without assembling the URI, and the positive conformance fixtures check that measurement agrees with rendering. `Template::diff_contract` reports selected static changes for API reviews; it does not prove URI equivalence.

Run from a source checkout:

```sh
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon run examples/api --target wasm-gc
```

`moon run examples/mcp --target wasm-gc` and `moon run examples/hypermedia --target wasm-gc` demonstrate two further uses. The [main README](README.md) documents the API, security boundaries, and conformance scope.

The runtime implementation is original. Apache-2.0 test fixtures from [uri-templates/uritemplate-test](https://github.com/uri-templates/uritemplate-test) are pinned and attributed in [THIRD_PARTY.md](THIRD_PARTY.md). The project itself is Apache-2.0 licensed.
