<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0006: UniAccurate as the EFT engine

- Status: Accepted
- Date: 2026-07-22
- Scope: UniMath

## Context

Error-free transforms (EFT) — `twoSum`, `twoProduct`, and the Shewchuk
expansion primitives (`twoSquare`, `twoDiffTail`, `growExpansion`,
`fastExpansionSumZeroElim`, `scaleExpansionZeroElim`, `estimate`) — underpin
the compensated summation used by the analysis cores. The original
UniversalMath carried an `AccurateSums` fork. A sibling project already
provides a dedicated EFT engine: **UniAccurate**.

## Decision

- UniMath depends on UniAccurate
  (`requires "https://github.com/lituus-lab/UniAccurate#main"`), declared in
  `vgraph.cfg [engines]` so any other `Uni*` name would be a back-edge.
- `src/UniMath/eft.nim` is a **thin re-export** of UniAccurate (primitives +
  expansions). UniMath adds no EFT C ABI: UniAccurate already owns the `ua_*`
  float64 EFT C ABI.
- The Shewchuk expansion primitives live in UniAccurate, not UniMath: they are
  general EFT primitives, with their own decimal-oracle tests, and are
  reusable by any downstream consumer. UniAccurate's U1 commit landed them
  before the UniMath `eft` slice.
- `config.nims` mirrors UniAccurate's FMA policy, since UniAccurate's sources
  compile under UniMath's flags: `-ffp-contract=off` on GCC/Clang for both
  amd64 and arm64 — EFT identities require the compiler not to contract
  `a + b * c` into an FMA, and clang contracts by default on both. `-mfma`
  stays opt-in behind `-d:useFMA`: it is a target-arch switch, so a default
  build carrying it would fault on any amd64 without FMA3.

## Consequences

One EFT implementation across the family, owned where it belongs. UniMath's
analysis modules get compensated summation without vendoring a fork, and the
EFT surface stays out of UniMath's C ABI to avoid duplicating UniAccurate's.
