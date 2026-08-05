# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Per-backend mathematical constants at the precision of the backend.
##
## - `BigFloat`: `pi` via Machin's formula `16*atan(1/5) - 4*atan(1/239)` and
##   `e` via the Taylor series of `exp(1)` — genuinely arbitrary precision (a
##   float64 literal would cap the constant at ~53 correct bits).
## - `Fixed`: grids of `<= 52` fractional bits — the float64 literal is exact
##   on the grid, so `piFixed`/`eFixed` round it through `toFixed`.
##
## `atanTaylor` comes from `trigonometry`; `constants` sits above it in the
## internal layer DAG. Rational `pi` lives in `rational_math` (a controlled
## approximation), not here.
import std/math
import contracts
import ./float
import ./fixed
import ./trigonometry

func piBigFloat*(precision: int = 256, terms: int = 96): BigFloat {.contractual.} =
  ## `pi` in arbitrary precision via Machin's formula
  ## `pi = 16*atan(1/5) - 4*atan(1/239)`. Convergence is ~4.6 bits/term for
  ## `atan(1/5)`, so 96 terms comfortably cover 256 bits; raise `terms` with
  ## `precision`.
  ensure:
    not result.isZero
  body:
    let fromIntP = func (v: int): BigFloat = initBigFloat(float64(v), precision)
    let one = fromIntP(1)
    let invFive = one / fromIntP(5)
    let inv239 = one / fromIntP(239)
    let a5 = atanTaylor(invFive, terms)
    let a239 = atanTaylor(inv239, terms)
    fromIntP(16) * a5 - fromIntP(4) * a239

func eBigFloat*(precision: int = 256, terms: int = 64): BigFloat {.contractual.} =
  ## `e` in arbitrary precision as the sum of `1/k!` (the series of `exp(1)`).
  ## Factorial convergence: 64 terms exceed 256 bits.
  ensure:
    not result.isZero
  body:
    let fromIntP = func (v: int): BigFloat = initBigFloat(float64(v), precision)
    var term = fromIntP(1)
    result = fromIntP(1)
    for k in 1 .. terms:
      term = term / fromIntP(k)
      result = result + term

func piFixed*[T; FracBits: static[int]](): Fixed[T, FracBits] {.contractual.} =
  ## `pi` on the `Q(FracBits)` grid. For `FracBits <= 52` the float64 literal
  ## is exact at the grid resolution. Honest `body:` (no `ensure:`): a
  ## storage-polymorphic nonzero check would recurse into the contracted `cmp`
  ## for `BigInt` storage, and there is no uniform non-contracted `isZero`
  ## across the `int64`/`BigInt` storage set. The `FracBits <= 52` shape guard
  ## is a compile-time `doAssert`; the `toFixed` overflow guard protects the
  ## construction; correctness is exercised by the test suite.
  body:
    static: doAssert FracBits <= 52,
      "FracBits > 52: go through piBigFloat then toFixed"
    result = toFixed[T, FracBits](PI)

func eFixed*[T; FracBits: static[int]](): Fixed[T, FracBits] {.contractual.} =
  ## `e` on the `Q(FracBits)` grid. Same contract as `piFixed`.
  body:
    static: doAssert FracBits <= 52,
      "FracBits > 52: go through eBigFloat then toFixed"
    result = toFixed[T, FracBits](E)
