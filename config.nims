# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniMath build config. Mirrors UniAccurate's FMA policy: `eft.nim` re-exports
## UniAccurate, whose sources compile under *this* project's flags, so the two
## must agree or the EFT identities hold in one build and not the other.
##
## Two separate concerns:
##
##   1. `-ffp-contract=off` (correctness) — the C compiler must never rewrite
##      `a*b - c` into a fused `fma(a,b,-c)`. That contraction breaks the
##      Dekker error identity of `twoProduct`, whose `ah*bh - result[0]` term
##      has to round separately. clang contracts by default on amd64 and arm64
##      alike, so the guard covers both. GCC does not contract by default and
##      MSVC's `/fp:precise` already forbids it (and would not understand the
##      flag), hence the GCC/Clang guard.
##
##   2. `-mfma` (amd64, opt-in with `-d:useFMA`) — lets the compiler inline the
##      C99 `fma` to a single instruction, but it is a *target-arch* switch, not
##      a CPU check: a generic wheel built with it faults on any amd64 older
##      than Haswell/Piledriver. Off by default, so libm `fma` stays a call the
##      platform dispatches (glibc IFUNC). arm64 has FMA in the base ISA.
##
## The opt-in SIMD backend (`-d:simd`) needs no ISA flag of its own: it uses
## NEON on arm64 and SSE2 on amd64, both base ISA.
when defined(gcc) or defined(clang):
  switch("passC", "-ffp-contract=off")
  when defined(amd64) and defined(useFMA):
    switch("passC", "-mfma")
