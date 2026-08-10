# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Generic complex `Complex[T] = object` (re, im) over any `Field` component:
## `float32`/`float64`, `BigFloat`, `Rational[T]`, `Fixed[T, FracBits]`. The
## type and its arithmetic need nothing beyond `Field` (`+ - * /`, unary `-`,
## `fromInt`); the transcendentals in `complex_math` need an ordered component
## with `sqrt`/`abs`/`arctan2` on top.
##
## Zero is built with `fromInt(T, 0)`, never `default(T)`: `default(Rational)`
## is `0/0`, which violates the positive-denominator invariant. Bodies only —
## no inline `ensure:`: a component postcondition delegates to `T`'s contracted
## `cmp`/`==` for `BigFloat`/`Rational` storage (recursion doctrine), and the
## field-level ones would restate the body. The identities are exercised by
## `tests/test_complex.nim`.
import ../arithmetic
import contracts

type
  Complex*[T] = object
    ## Cartesian complex number `re + im*i`.
    re*: T
    im*: T

func complex*[T](re, im: T): Complex[T] {.inline.} =
  ## Cartesian constructor.
  Complex[T](re: re, im: im)

func complex*[T](re: T): Complex[T] {.inline.} =
  ## Real embedding `re + 0i`.
  Complex[T](re: re, im: fromInt(T, 0))

func imagUnit*[T](TT: typedesc[Complex[T]]): Complex[T] {.inline.} =
  ## `i` for the component type — `imagUnit(Complex[float64])`.
  Complex[T](re: fromInt(T, 0), im: fromInt(T, 1))

# Concept construction: `fromInt(Complex[T], v)` = v + 0i, so the generic
# `Field` series (`expTaylor`, `sinTaylor`, `factorial`, ...) build their
# integer coefficients without an injected constructor.
func fromInt*[T](TT: typedesc[Complex[T]], v: int): Complex[T] {.inline.} =
  Complex[T](re: fromInt(T, v), im: fromInt(T, 0))

func conj*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## Complex conjugate `re - im*i`.
  body:
    Complex[T](re: z.re, im: -z.im)

func norm2*[T](z: Complex[T]): T {.contractual.} =
  ## Squared modulus `re^2 + im^2`, as a component value. Exact on the exact
  ## backends — unlike `abs`, which takes a square root and only approximates.
  ## It is also the quantity `/` divides by, so a caller comparing magnitudes
  ## should prefer it over squaring `abs`.
  body:
    z.re * z.re + z.im * z.im

func isZero*[T](z: Complex[T]): bool {.inline.} =
  mixin `==`
  z.re == fromInt(T, 0) and z.im == fromInt(T, 0)

func isReal*[T](z: Complex[T]): bool {.inline.} =
  ## True when the imaginary part is exactly zero.
  mixin `==`
  z.im == fromInt(T, 0)

func isImaginary*[T](z: Complex[T]): bool {.inline.} =
  ## True when the real part is exactly zero (`0` counts as both).
  mixin `==`
  z.re == fromInt(T, 0)
