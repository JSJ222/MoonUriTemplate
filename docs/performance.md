# Performance baseline

The fixed [native benchmark](../benchmarks/main/main.mbt) compiles one URI Template and expands it 20,000 times with a changing path ID plus a three-item list and two scalar query values. It prints a checksum of `1568890` output characters so the work remains observable. The benchmark is a repeatable workload, not a throughput promise for other machines or larger templates.

On the local Windows host with MoonBit `moonc v0.10.14`, a release native build was warmed before running the executable directly five times. Wall-clock samples were 495.3, 365.4, 350.4, 348.6, and 332.1 ms; the median was 350.4 ms. These samples include process startup and allocation. There is no earlier implementation measured under identical conditions, so they do not support a percentage speedup claim.

Reproduce with `moon build --target native --release` and run `_build/native/release/build/benchmarks/main/main.exe` under a wall-clock timer. On other operating systems, locate the benchmark executable under `_build/native/release/build/benchmarks/main/`. For algorithmic limits, see [architecture](architecture.md): parsing is expected O(T), and expansion is expected O(T + B + V + O), accounting for repeated variable references. The 1,024-expression and 512-distinct-variable stress tests verify configured boundaries, but do not establish asymptotic scaling by measurement.
