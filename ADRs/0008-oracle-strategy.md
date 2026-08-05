<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0008: Oracle strategy

- Status: Accepted
- Date: 2026-07-22
- Scope: UniMath testing

## Context

Multi-precision arithmetic and transcendentals need an independent reference
to validate against — the library under test must not be its own oracle. The
original UniversalMath carried text-over-pipe oracles. UniMath re-homes them
under `oracles/` but keeps them out of the default gate, because they need
native libraries not available on every CI OS.

## Decision

- **Independent oracles** under `oracles/`:
  - `mpfr_oracle.c` — MPFR reference for `BigFloat` transcendentals (C, needs
    `libmpfr`; built by `nimble buildOracles`).
  - `gmp_oracle.c` — GMP reference for `BigInt` / `Rational` (C, needs
    `libgmp`; built by `nimble buildOracles`).
  - `eft_oracle.py` — decimal EFT reference (Python, needs no build).
  - `oracles/oracle.nim` — Nim bridge that pipes inputs to the C oracles and
    reads back the reference result.
- `nimble testOracle` builds the oracles and runs the oracle-backed tests
  (`tests/test_*_oracle.nim`). It is **not** in the default gate — run it
  explicitly on a host with `libmpfr`/`libgmp` (linux/macOS via pkg-config).
- The compiled oracle binaries are gitignored; `lint` does not scan `oracles/`
  (only `src`/`tests`/`examples`/`book`), so the C oracles do not need to be
  nimpretty-clean.
- Each package's oracle test lands in that package's vertical slice, alongside
  the in-repo deterministic tests.

## Consequences

Precision parity is checked against independent GMP/MPFR references on hosts
that have them, without forcing native-library deps on the default CI gate.
The in-repo deterministic tests (Nim `unittest` + the randomized property
suite, `tests/test_properties.nim`) carry the default gate; the oracles are
the deeper, opt-in precision check. The `bench/` parity section
(`bench/bench_transcendentals.nim`) gives a fast, always-on sanity check of
`BigFloat` against the float64 `math` oracle.