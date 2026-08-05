# bench — perf and precision-parity harness

Isolated benchmark suite for UniMath. **Not part of the default gate**
(`test` / `testAll` / `lint` / `checkVGraph` / `docs`); run it explicitly:

```bash
nimble bench          # Nim self-timing: perf + precision parity
nimble benchSpeed     # C: UniMath vs native GMP/MPFR (needs libmpfr/libgmp)
```

Both `bench` targets build with `-d:release` so the `NimContracts`
`{.contractual.}` postconditions compile away and the timings reflect the
shipped code path. `benchSpeed` links the release static lib (`libUniMath.a`)
plus `libmpfr`/`libgmp` via pkg-config — Linux/macOS only.

## Targets

- `bench_arithmetic.nim` — BigInt add / mul (64- and 1024-bit) / div, integer
  `isqrt`, and `Fixed[int64, 32]` add / mul / div. Reports ns/op and ops/sec.
- `bench_transcendentals.nim` — transcendentals across the three backends
  (`BigFloat` via `float_math`, `Fixed` Q32.32 via `math_router`,
  `Rational[BigInt]` via `rational_math`), plus a precision-parity section that
  compares the 256-bit `BigFloat` result against the float64 `math` oracle and
  reports the absolute error.
- `bench_speed.c` — head-to-head speed of the UniMath C ABI against the native
  GMP/MPFR oracles at matching precision (256-bit `BigFloat`; BigInt operand
  sizes built identically on both sides). Prints ns/op for each side and the
  `uni/orc-alloc` ratio (`<1.0` means UniMath is faster).

## Reading the numbers

Every timed result feeds a non-inline sink that writes a global printed at the
end of the run, so the release optimizer cannot dead-code-eliminate the pure
`func` bodies. The `Fixed` add is loop-carried (`xa = xa + y`): a plain int64
add with loop-invariant operands would be hoisted out of the loop and read as
~0 ns/op.

The parity section demonstrates that `BigFloat` tracks the IEEE-64 reference to
within the double's own precision (|err| at or below a few × 10⁻¹⁷) — the same
precision target the original UniversalMath packages were validated against.

### `benchSpeed` fairness

The UniMath handle ABI allocates a fresh result per op and the caller frees it
(`*_destroy`). To match that allocation model on the oracle side, every GMP/MPFR
op is timed two ways:

- **orc-reuse** — init the result once, overwrite it every iteration. This is
  the idiomatic, fastest oracle usage and the number a tuned GMP/MPFR program
  actually sees.
- **orc-alloc** — `init` + `clear` the result every iteration, the
  apples-to-apples match to UniMath's per-op allocation.

The `uni/orc-alloc` ratio is the fair comparison. Expect it to be `> 1.0`:
GMP/MPFR are decades-tuned C libraries and UniMath pays a per-op handle
allocation the oracles do not (under `reuse`). The benchmark exists to measure
that gap honestly, not to claim a win — `ln` is within ~2×, the BigInt and
transcendental cores are farther back, and the ratio tells you exactly where
the allocation and algorithmic costs are.