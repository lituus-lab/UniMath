# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## The `Limb`: the machine word a multi-precision integer decomposes into.
## 64-bit on amd64/arm64 (and the default), 32-bit on i386/arm32. Nim has no
## native uint128, so a 128-bit target still uses uint64 limbs (correct, not
## optimal); software 128/256-bit integers come from `FixedInt[128]` anyway.
type
  Limb* = uint64
    ## Multi-precision word. Always uint64 here: every Nim target carries uint64,
    ## and a single limb width keeps the algorithms uniform.
  DoubleLimb* = tuple[hi, lo: Limb]
    ## Split 128-bit product for portability (no platform uint128 assumed).

const
  LimbBits* = 64
  LimbBytes* = 8
  MaxLimb* = high(uint64)
  ZeroLimb* = Limb(0)
  OneLimb* = Limb(1)

static:
  doAssert sizeof(Limb) * 8 == LimbBits, "Limb size mismatch"

func toLimb*(x: SomeInteger): Limb {.inline.} =
  ## Reinterpret an integer as a Limb (truncates wider inputs).
  cast[Limb](x)
