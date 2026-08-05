<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0001: Sibling package dependencies

- Status: Accepted
- Date: 2026-07-15
- Scope: `requires` in `UniMath.nimble`, checked by `nimble checkVGraph`

## Decision

`vgraph.cfg`'s `[engines]` section is the exhaustive list of similarly-prefixed
packages this repo may name in a `requires` line; any name absent from it is a
violation caught by `nimble checkVGraph`. Declared today: UniAccurate
(ADR-0006), the EFT engine `src/UniMath/eft.nim` re-exports. Adding another
entry is a deliberate, reviewed exception, not a default.

Non-domain infrastructure (`nim`, `NimContracts`, `nimsimd`) is unaffected and
unchecked by this rule.
