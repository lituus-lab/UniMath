# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Per-backend constants: `pi`/`e` for `BigFloat` (Machin's formula / `exp(1)`
## series) and `Fixed` (float64 literal exact on the `<= 52`-bit grid). The
## beyond-float64 precision of `piBigFloat`/`eBigFloat` is exercised by the
## `float_math` MPFR oracle (commit 23); here we check the float64-exact and
## Q-grid paths. The `FracBits > 52` guard is a compile-time `doAssert`, so it
## cannot be runtime-tested (such a call would fail the build).
import std/[unittest, math]
import UniMath

suite "Constants — BigFloat":
  test "piBigFloat is float64-exact at 256 bits":
    check toFloat64(piBigFloat(256)) == PI
  test "piBigFloat at 128 bits rounds to the float64 pi":
    check toFloat64(piBigFloat(128)) == PI
  test "eBigFloat is float64-exact at 256 bits":
    check toFloat64(eBigFloat(256)) == E
  test "eBigFloat is positive (ensure: not isZero)":
    check toFloat64(eBigFloat(256)) > 0.0

suite "Constants — Fixed":
  test "piFixed on the Q32.32 grid":
    check abs(toFloat64(piFixed[int64, 32]()) - PI) < pow(2.0, -32.0)
  test "eFixed on the Q32.32 grid":
    check abs(toFloat64(eFixed[int64, 32]()) - E) < pow(2.0, -32.0)
  test "piFixed on the Q16.16 grid":
    check abs(toFloat64(piFixed[int64, 16]()) - PI) < pow(2.0, -16.0)
  test "eFixed on the Q16.16 grid":
    check abs(toFloat64(eFixed[int64, 16]()) - E) < pow(2.0, -16.0)
