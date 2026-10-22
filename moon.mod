// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "JSJ222/moonuritemplate"

version = "0.3.0"

readme = "README.mbt.md"

repository = "https://github.com/JSJ222/MoonUriTemplate"

license = "Apache-2.0"

keywords = [ "api-contract", "openapi", "schema", "incremental", "rfc6570" ]

preferred_target = "wasm-gc"

import {
  "moonbitstack/moonschema@0.2.0",
}

description = "Offline API contract workspaces, dependency-aware updates and consumer upgrade gates; RFC 6570 compatibility"
