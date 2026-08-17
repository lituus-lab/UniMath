# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Complex arithmetic: `+`, `-`, `*`, `/`, unary `-`, and the mixed
## complex-scalar forms. Everything here needs only the `Field` operations on
## the component `T`, so it holds for `float64`, `BigFloat`, `Rational` and
## `Fixed` alike.
##
## `/` picks its formula per instantiation. When `T` carries an order and an
## `abs` (every real backend does) it uses Smith's algorithm, which scales by
## the larger denominator component so that `complex(1e300, 1e300) /
## complex(1e300, 1e300)` stays `1+0i` instead of collapsing to NaN through an
## overflowing `c^2 + d^2`. A component without an order falls back to the
## textbook formula, which is exact on the exact backends where overflow is
## either impossible (`BigInt`-backed) or already a raise.
##
## Bodies only — no inline `ensure:`: a postcondition on the real/imaginary
## parts either restates the body or compares through `T`'s contracted
## `cmp`/`==` (recursion doctrine). The algebraic identities (ring laws,
## `z * conj(z) == norm2(z)`, `z / z == 1`) are exercised by
## `tests/test_complex.nim` and the property suite.
import ../arithmetic
import ./complex_type
import contracts

func `+`*[T](x, y: Complex[T]): Complex[T] {.contractual, inline.} =
  body:
    Complex[T](re: x.re + y.re, im: x.im + y.im)

func `-`*[T](x, y: Complex[T]): Complex[T] {.contractual, inline.} =
  body:
    Complex[T](re: x.re - y.re, im: x.im - y.im)

func `-`*[T](x: Complex[T]): Complex[T] {.contractual, inline.} =
  ## Unary negation.
  body:
    Complex[T](re: -x.re, im: -x.im)

func `*`*[T](x, y: Complex[T]): Complex[T] {.contractual, inline.} =
  ## `(a+bi)(c+di) = (ac - bd) + (ad + bc)i`. The four-multiply form, not
  ## Karatsuba's three: the three-multiply variant trades a multiplication for
  ## extra additions and loses accuracy on the floating backends.
  body:
    Complex[T](re: x.re * y.re - x.im * y.im,
               im: x.re * y.im + x.im * y.re)

func `/`*[T](x, y: Complex[T]): Complex[T] {.contractual.} =
  ## Division by zero raises `DivByZeroDefect` (body guard, survives release),
  ## matching `Rational`'s `/`. See the module header for the two formulas.
  body:
    mixin abs
    if y.isZero:
      raise newException(DivByZeroDefect, "Complex division by zero")
    when compiles(abs(y.re) < abs(y.im)):
      # Smith, CACM 5(8), 1962: divide through by the larger component so the
      # intermediate ratio stays in [-1, 1] and no squared magnitude is formed.
      if abs(y.im) < abs(y.re):
        let r = y.im / y.re
        let den = y.re + y.im * r
        Complex[T](re: (x.re + x.im * r) / den,
                   im: (x.im - x.re * r) / den)
      else:
        let r = y.re / y.im
        let den = y.re * r + y.im
        Complex[T](re: (x.re * r + x.im) / den,
                   im: (x.im * r - x.re) / den)
    else:
      let den = y.norm2
      Complex[T](re: (x.re * y.re + x.im * y.im) / den,
                 im: (x.im * y.re - x.re * y.im) / den)

# ------------------------------------------------------------------------------
# Mixed complex-scalar forms. Spelled out rather than routed through
# `complex(s)` so a scalar multiply costs two component multiplies, not four.
# ------------------------------------------------------------------------------

func `*`*[T](x: Complex[T], s: T): Complex[T] {.contractual, inline.} =
  body:
    Complex[T](re: x.re * s, im: x.im * s)

func `*`*[T](s: T, x: Complex[T]): Complex[T] {.contractual, inline.} =
  body:
    Complex[T](re: s * x.re, im: s * x.im)

func `/`*[T](x: Complex[T], s: T): Complex[T] {.contractual, inline.} =
  ## A zero scalar raises through `T`'s own `/` (body path, survives release).
  body:
    Complex[T](re: x.re / s, im: x.im / s)

func `+`*[T](x: Complex[T], s: T): Complex[T] {.contractual, inline.} =
  body:
    Complex[T](re: x.re + s, im: x.im)

func `+`*[T](s: T, x: Complex[T]): Complex[T] {.contractual, inline.} =
  body:
    Complex[T](re: s + x.re, im: x.im)

func `-`*[T](x: Complex[T], s: T): Complex[T] {.contractual, inline.} =
  body:
    Complex[T](re: x.re - s, im: x.im)

func `-`*[T](s: T, x: Complex[T]): Complex[T] {.contractual, inline.} =
  body:
    Complex[T](re: s - x.re, im: -x.im)

func inv*[T](x: Complex[T]): Complex[T] {.contractual.} =
  ## Multiplicative inverse `1/x`. Raises `DivByZeroDefect` on zero.
  body:
    fromInt(Complex[T], 1) / x
