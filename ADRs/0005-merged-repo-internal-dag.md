<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0005: Merged-repo internal DAG

- Status: Accepted
- Date: 2026-07-22
- Scope: UniMath

## Context

The original UniversalMath was a monorepo of seven Nim packages
(UniArithmetic, UniFixed, UniFloat, UniRational, UniInterval,
UniMath-analysis, UniLinalg) plus a shared C ABI and Python binding. UniMath
absorbs the six non-linalg packages as internal modules; UniLinalg stays a
separate repo that depends on UniMath, not the reverse.

## Decision

UniMath is a single repo with a documented internal layer DAG enforced by
`vgraph.cfg [layers]` (lowest → highest):

```text
arithmetic  fixed  float  rational  interval      type layers (interval is a leaf)
eft                                            thin re-export of UniAccurate (ADR-0006)
roots  exponential  trigonometry  hyperbolic  special     generic + fixed cores
constants  reduction  float_math  rational_math  conversions  math_router   dispatch/integration
c_api                                                          per-package C ABI (ADR-0007)
```

- Each absorbed package is a **sub-umbrella** (`src/UniMath/<pkg>.nim` +
  `src/UniMath/<pkg>/*.nim`) so a cross-package import is one line
  (`import ../arithmetic`). `vgraph.cfg` maps both `<pkg>.nim` and
  `<pkg>/*.nim` to layer `<pkg>`.
- The top umbrella `src/UniMath.nim` re-exports the sub-umbrellas, the flat
  analysis modules, and `eft`. `c_api.nim` imports the umbrella (never the
  reverse → no cycle).
- A module imports its own layer and any lower layer, never a higher one. A
  back-edge fails `nimble checkVGraph`.

## Consequences

One repo, one `nimble` build, one C ABI, one Python binding — but the internal
layering keeps the packages decoupled and reviewable. `vgraph.cfg [engines]`
(ADR-0001) declares only `UniAccurate`; UniLinalg depends on UniMath, not the
reverse, so it isn't declared here.