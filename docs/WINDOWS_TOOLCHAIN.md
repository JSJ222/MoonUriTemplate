# MoonBit 0.10.16 on Windows

Verified: `moon 0.1.20261016 (1af328f)`, `moonc v0.10.16+b1a0e846e`,
`moonrun 0.1.20261016`. This Windows driver passes extended DOS paths such as
`\\?\E:\...` to OCaml tools that reject them with `Sys_error`.

```powershell
./tools/windows/moon.ps1 check --target all --deny-warn
./tools/windows/moon.ps1 test --target all --deny-warn
./tools/windows/moon.ps1 info
./tools/windows/moon.ps1 fmt --check
./tools/windows/moon.ps1 run examples/incremental_links --target wasm-gc
```

The optional wrapper requires MSVC Build Tools. It builds ignored executables
under `_build`, sets process-local overrides and restores previous values. The
C adapter preserves argv quoting/exit status, removes only extended DOS drive
prefixes and launches installed official tools without a shell. UNC paths and
source content are unchanged. It is not an upstream compiler patch.

After a toolchain upgrade, installed core bundles must match that toolchain. CI
rebundles core through the adapter. Linux uses ordinary Moon commands. LF Git
checkouts keep formatting checks stable. The current formatter normalizes `Int`
to `Int32` and optional argument declarations to `~`; generated interfaces are
refreshed with the same version. Integer width and RFC expansion are unchanged.

The argv utility is reused from this workspace's MoonTUF compatibility code
under Apache-2.0, with provenance in THIRD_PARTY.md. It contains no URI logic.
