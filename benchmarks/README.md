# Native float64 facade benchmark

The benchmark measures two preallocated 262,144-value workloads: a numeric
transform (`sqrt + log10`) and a polar kernel (`sin + cos + hypot`). Each
workload is executed through direct `std/math` calls and through UniMath's
native facade in the same release process. Outputs must compare exactly before
a sample is accepted.

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
| transform | 0.6046 ms | 0.6054 ms | +0.13% |
| polar | 1.2013 ms | 1.1813 ms | -1.67% |

The transform result is effectively equal at this resolution. The polar result
is an observation from three run means, not a portable speedup claim; compiler
and libm lowering may change it. Standard operations are the original
`std/math` declarations re-exported by UniMath; only `log1p`, `expm1` and
`sinCos` are additional templates.
