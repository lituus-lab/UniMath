# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Hyperbolic CORDIC tests: in-domain `exp`/`sinh`/`cosh`/`tanh`, the
## `cosh^2 - sinh^2 = 1` identity, and the convergence-domain guard. Hyperbolic
## CORDIC converges only for `|z| <= sum atanh(2^-i) ~ 1.1182` (no range
## reduction — the functions are not periodic); beyond it the core raises
## `ValueError` instead of silently saturating. MinInt angles must raise too
## (the guard compares `z` against `+/-budget`, never negating `z`).
import std/[unittest, math]
import UniMath

suite "Hyperbolic CORDIC — in-domain":
  test "exp/sinh/cosh at 1.0 (Q16.16)":
    let one = toFixed[int64, 16](1.0)
    check abs(toFloat64(expCordic(one)) - exp(1.0)) < 0.01
    check abs(toFloat64(sinhCordic(one)) - sinh(1.0)) < 0.01
    check abs(toFloat64(coshCordic(one)) - cosh(1.0)) < 0.01
  test "cosh^2 - sinh^2 = 1":
    let one = toFixed[int64, 16](1.0)
    let sh = sinhCordic(one)
    let ch = coshCordic(one)
    check abs(toFloat64(ch * ch - sh * sh) - 1.0) < 0.02
  test "tanh at 1.0":
    let one = toFixed[int64, 16](1.0)
    check abs(toFloat64(tanhCordic(one)) - tanh(1.0)) < 0.01
  test "near-boundary 1.1 (inside budget)":
    let a = toFixed[int64, 16](1.1)
    check abs(toFloat64(expCordic(a)) - exp(1.1)) < 0.05
    check abs(toFloat64(sinhCordic(a)) - sinh(1.1)) < 0.05
  test "negative in-domain sinh(-1.0) = -sinh(1.0) (odd)":
    let a = toFixed[int64, 16](-1.0)
    check abs(toFloat64(sinhCordic(a)) - sinh(-1.0)) < 0.01
  test "Q32 in-domain stays correct":
    let b = toFixed[int64, 32](1.0)
    check abs(toFloat64(expCordic(b)) - exp(1.0)) < 1e-3

suite "Hyperbolic CORDIC — convergence-domain guard":
  test "expCordic(2.0) raises (was silent 3.059 vs e^2=7.389)":
    let a = toFixed[int64, 16](2.0)
    expect ValueError:
      discard expCordic(a)
  test "sinhCordic(1.5) raises (was silent 1.366 vs sinh(1.5)=2.129)":
    let a = toFixed[int64, 16](1.5)
    expect ValueError:
      discard sinhCordic(a)
  test "coshCordic(1.5) raises":
    let a = toFixed[int64, 16](1.5)
    expect ValueError:
      discard coshCordic(a)
  test "tanhCordic(2.0) raises (projection path)":
    let a = toFixed[int64, 16](2.0)
    expect ValueError:
      discard tanhCordic(a)
  test "negative out-of-domain sinhCordic(-2.0) raises (symmetric budget)":
    let a = toFixed[int64, 16](-2.0)
    expect ValueError:
      discard sinhCordic(a)
  test "Q32 out-of-domain raises":
    let a = toFixed[int64, 32](2.0)
    expect ValueError:
      discard expCordic(a)
  test "MinInt angle Q52 (toFixed(-2048.0)=low(int64)) raises":
    let a = toFixed[int64, 52](-2048.0)
    check a.data == low(int64)
    expect ValueError:
      discard expCordic(a)
    expect ValueError:
      discard sinhCordic(a)
  test "MinInt angle Q16 (most-negative representable) raises":
    let a = initFixed[int64, 16](low(int64))
    expect ValueError:
      discard expCordic(a)
