<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0004: UniMath conventions

- Status: Accepted
- Date: 2026-07-15
- Scope: UniMath itself

## Layout

```text
UniMath.nimble              package + tasks
config.nims                 compiler-conditional build flags (-ffp-contract=off)
vgraph.cfg                  internal layer DAG + declared engines
src/UniMath.nim             umbrella
src/UniMath/<pkg>.nim       sub-umbrella per absorbed package
src/UniMath/<pkg>/*.nim     package modules
src/UniMath/c_api.nim       C ABI
include/UniMath.h           hand-written C header
tests/ tests/c/             Nim + C ABI tests
examples/                   Nim + C demos
py/                         Cython binding + pytest
book/                       nimib book
ADRs/                       0001–0004 (+ domain ADRs)
.github/workflows/ci.yml    3-OS Nim + C ABI + Python
LICENSE NOTICE CONTRIBUTING.md SECURITY.md .gitignore README.md AGENTS.md CLAUDE.md
```

## Naming

- Nim package/module: `UniMath` (PascalCase); sub-packages `arithmetic`, `fixed`,
  `float`, `rational`, `interval`, and the analysis modules.
- C library: `libUniMath`. C header: `UniMath.h`.
- C symbol prefix: `unimath_` (the full prefix, not the short `um_` — the
  family's short-prefix convention is relaxed here so the C surface is
  unambiguous and grep-friendly).

## Conventions

- NimContracts `{.contractual.}` + `require:`/`ensure:`/`body:`, compiled away
  under `-d:release`. The C ABI never raises — it clamps out-of-range input.
- A postcondition is cheaper than the body; it never re-derives the result.
- English comments, terse, describe what is done. No "deprecated".
- Internal layer DAG enforced by `vgraph.cfg` (ADR-0001); a module imports its own
  layer and any lower one, never a higher one.

## CI gates

- `nimble testCi` + `testCiRelease` on ubuntu/macOS/Windows.
- `nimble ctest` on linux/macOS.
- `nimble pyTest` on linux.
