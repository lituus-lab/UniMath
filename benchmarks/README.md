# Native float64 facade benchmark

The benchmark measures three preallocated 262,144-value workloads: a numeric
transform (`sqrt + log10`), a polar kernel (`sin + cos + hypot`), and
`regularizedIncompleteBeta(x, 2, 5)` across evenly spaced probabilities. The
first two workloads are executed through direct `std/math` calls and through
UniMath's native facade in the same release process. Their outputs must compare
exactly before a sample is accepted. The beta phase is an absolute throughput
measurement of UniMath's continued-fraction implementation, not a comparison
against another library.

`nimble benchmarkNativeFloatBaseline` performs three independent processes,
twenty measured iterations per process and three warmups per process, then
writes the median of the three run means to
`build/native-float-baseline.json`. Allocation and input construction are
outside the measured windows; the complete loop and output writes are inside.
Direct and facade order alternates on every iteration, with the polar order
opposed to the transform order, so neither provider always runs first.

This checks facade overhead. It does not claim that UniMath provides a faster
libm, and results from different machines are not directly comparable.

The versioned Apple M4 baseline records:

| Workload | Direct | UniMath facade | Observed difference |
|---|---:|---:|---:|
| transform | 0.6141 ms | 0.5818 ms | -5.27% |
| polar | 1.1925 ms | 1.1719 ms | -1.73% |

The regularized-beta median is 10.8135 ms, or 24.24 million values per second.

All differences in the table are observations from three run means, not
portable performance claims; compiler, libm and CPU changes may alter them.
Standard operations are the original
`std/math` declarations re-exported by UniMath; only `log1p`, `expm1` and
`sinCos` are additional templates.
