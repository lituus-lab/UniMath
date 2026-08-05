<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0007: Per-package C ABI

- Status: Accepted
- Date: 2026-07-22
- Scope: UniMath C ABI, Python binding

## Context

ADR-0003 fixes the engine/shell split: a hand-written `include/UniMath.h`
kept in sync with `src/UniMath/c_api.nim`, and `tests/c` linking the header
against the lib as an ABI-drift detector. The original UniversalMath exposed
only the type handles plus `BigFloat` transcendentals over its shared C ABI.
UniMath absorbs six packages and wants each to be exercisable from C and
Python, not just the types.

## Decision

- One C ABI module (`c_api.nim`) at the top of the internal DAG
  (ADR-0005), but the surface is **organized per package**: `unimath_bigint_*`,
  `unimath_fixed_*`, `unimath_bigfloat_*`, `unimath_rational_*`,
  `unimath_interval_*`, and a namespace per analysis module
  (`unimath_bigfloat_sin`, `unimath_fixed_sqrt` via the router, the
  `unimath_conversions_*` cross-type matrix, etc.). Symbol prefix is
  `unimath_` (ADR-0004).
- **Handle model.** `BigInt`, `BigFloat`, `Rational` are opaque `void*`
  handles backed by Nim `ref` values pinned with `GC_ref` under `--mm:arc`
  (ADR-0003); `unimath_init()` brings up the allocator, each `*_destroy`
  unpins with `GC_unref`. `Fixed` is a raw `int64` Q-format value (no handle);
  `Interval` is a `(lo, hi)` pair of `double` returned by value
  (`unimath_interval`).
- **Never raises.** The C ABI clamps/NULLs: nil in → nil out for handle procs;
  out-of-range or defect input on the int64 Q-format procs clamps to `0`; a
  domain error on the interval procs returns a NaN interval — they take and
  return `unimath_interval` by value, so there is no nil to pass. No Nim
  exception crosses the boundary.
- **Python binding.** Cython over the shared lib (`py/unimath/_core.pyx`), one
  class per package (`BigInt`, `Fixed`, `BigFloat`, `Rational`, `Interval`,
  plus the analysis namespaces), coercing Python values into the C surface.
- Grown one package at a time, in the package's vertical slice, so `ctest` +
  `pyTest` stay green after each commit.

## Consequences

The C and Python surfaces cover every package, not just the types. The
handle/pin pattern is reused across `BigInt`/`BigFloat`/`Rational`; `Fixed`
and `Interval` stay value-typed at the boundary to avoid handle overhead.