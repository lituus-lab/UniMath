# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Transcendental functions for `Rational[T]`, dispatched over the generic
## Taylor / atanh / Newton cores.
##
## `Rational[T]` satisfies the `Field` concept, so the generic series apply
## directly: each term is an exact rational, and the truncation at `terms` makes
## the value approximate (not the arithmetic). Integer coefficients reach the
## series through the uniform `fromInt(Rational[T], n)` overload. This is the
## exact-arithmetic counterpart to `float_math`: no rounding, but the
## denominators grow with `terms` (bounded for `int64`, unbounded for `BigInt`).
##
## Contracts: `{.contractual.}` + `body:` only — no inline `ensure:`. These are
## approximate-algorithm dispatch wrappers; an `ensure:` recomputing the result
## would invoke the contracted `Rational` operators (recursion doctrine). The
## precision envelope is documented per-proc and verified externally (the value
## is exact per term, approximate to `terms`). The private `piRational` helper is
## intentionally non-contracted (ensures may only call non-contracted helpers).
import contracts
import ./rational
import ./arithmetic
import ./trigonometry/taylor
import ./exponential/taylor as exp_taylor
import ./exponential/logarithm_generic
import ./roots/isqrt
import ./special/gamma
import ./special/error_functions
import ./special/bessel

# ------------------------------------------------------------------------------
# Rational trigonometry (via Taylor)
# ------------------------------------------------------------------------------

func sin*[T](x: Rational[T], terms: int = 5): Rational[T] {.contractual.} =
  ## `sin(x)` via the generic Taylor core (truncated at `terms`). Each term is
  ## exact rational; the truncation makes the value approximate. No inline
  ## `ensure:` (recursion doctrine).
  body:
    taylor.sinTaylor(x, terms)

func cos*[T](x: Rational[T], terms: int = 5): Rational[T] {.contractual.} =
  ## `cos(x)` via the generic Taylor core. Approximate (truncated series).
  body:
    taylor.cosTaylor(x, terms)

func tan*[T](x: Rational[T], terms: int = 5): Rational[T] {.contractual.} =
  ## `tan(x) = sin(x)/cos(x)`. Raises `DivByZeroDefect` when `cos(x)` is zero
  ## (via the Rational `/` body path, survives release). Approximate.
  body:
    sin(x, terms) / cos(x, terms)

# ------------------------------------------------------------------------------
# Rational inverse trigonometry
# ------------------------------------------------------------------------------

func piRational[T](): Rational[T] {.inline.} =
  ## `pi` as the convergent `355/113` — error ~2.7e-7 (7 significant digits).
  ## A convergent of the continued fraction of pi avoids the int64 overflow that
  ## arises from the Machin formula (two Taylor series with coprime
  ## denominators). Non-contracted (private helper; ensures call only
  ## non-contracted helpers).
  initRational(fromInt(T, 355), fromInt(T, 113))

func atan*[T](x: Rational[T], terms: int = 5): Rational[T] {.contractual.} =
  ## `atan(x)` via the Gregory-Leibniz series with range reduction: `|x| > 1`
  ## folds to `pi/2 - atan(1/|x|)`. The default 5 terms keeps individual term
  ## denominators `<= q^9 * 315`, within int64 range when the input denominator
  ## `q <= ~100`; reduce `terms` for larger inputs to avoid `OverflowDefect`.
  ## Approximate (truncated series).
  body:
    let z0 = zero(Rational[T])
    let o1 = one(Rational[T])
    let neg = x < z0
    let ax = if neg: -x else: x
    var r: Rational[T]
    if ax <= o1:
      r = taylor.atanTaylor(ax, terms)
    else:
      let halfPi = piRational[T]() / fromInt(Rational[T], 2)
      r = halfPi - taylor.atanTaylor(o1 / ax, terms)
    if neg: -r else: r

func arctan*[T](x: Rational[T], terms: int = 5): Rational[T] {.contractual, inline.} =
  ## Alias for `atan`. Approximate.
  body:
    atan(x, terms)

func atan2*[T](y, x: Rational[T], terms: int = 5): Rational[T] {.contractual.} =
  ## Full-quadrant `atan2(y, x)`. `pi` is approximated as `355/113`
  ## (error ~2.7e-7), keeping intermediate denominators within int64 range for
  ## typical geometry inputs. Approximate.
  body:
    let z0 = zero(Rational[T])
    let pi = piRational[T]()
    let halfPi = pi / fromInt(Rational[T], 2)
    if x > z0:
      return atan(y / x, terms)
    elif x < z0:
      if y >= z0: return atan(y / x, terms) + pi
      else: return atan(y / x, terms) - pi
    else:
      if y > z0: return halfPi
      elif y < z0: return -halfPi
      else: return z0

func arctan2*[T](y, x: Rational[T], terms: int = 5): Rational[T] {.
    contractual, inline.} =
  ## Alias for `atan2`. Approximate.
  body:
    atan2(y, x, terms)

# ------------------------------------------------------------------------------
# Rational exponential & logarithmic
# ------------------------------------------------------------------------------

func exp*[T](x: Rational[T], terms: int = 10): Rational[T] {.contractual.} =
  ## `e^x` as an exact rational approximation (truncated series). Approximate.
  body:
    exp_taylor.expTaylor(x, terms)

func ln*[T](x: Rational[T], terms: int = 10): Rational[T] {.contractual.} =
  ## `ln(x)` via the fast-converging universal (atanh) series. Raises
  ## `ValueError` for `x <= 0` (body `raise` in `lnGeneric`, survives release).
  ## Approximate (truncated series).
  body:
    logarithm_generic.lnGeneric(x, terms)

func pow*[T](base, exponent: Rational[T], terms: int = 10): Rational[T] {.
    contractual.} =
  ## `base^exponent = exp(exponent·ln(base))`. Raises `ValueError` when
  ## `base <= 0` (via `ln`, body path, survives release). Approximate.
  body:
    exp(exponent * ln(base, terms), terms)

# ------------------------------------------------------------------------------
# Rational hyperbolic
# ------------------------------------------------------------------------------

func sinh*[T](x: Rational[T], terms: int = 10): Rational[T] {.contractual.} =
  ## `sinh(x) = (exp(x) - exp(-x)) / 2`. Approximate (truncated `exp`).
  body:
    let eX = exp(x, terms)
    let eNegX = exp(-x, terms)
    (eX - eNegX) / fromInt(Rational[T], 2)

func cosh*[T](x: Rational[T], terms: int = 10): Rational[T] {.contractual.} =
  ## `cosh(x) = (exp(x) + exp(-x)) / 2`. Approximate (truncated `exp`).
  body:
    let eX = exp(x, terms)
    let eNegX = exp(-x, terms)
    (eX + eNegX) / fromInt(Rational[T], 2)

func tanh*[T](x: Rational[T], terms: int = 10): Rational[T] {.contractual.} =
  ## `tanh(x) = sinh(x)/cosh(x)`. Raises `DivByZeroDefect` when `cosh(x)` is
  ## zero (never for real x, but the path is body-`raise`-safe). Approximate.
  body:
    sinh(x, terms) / cosh(x, terms)

# ------------------------------------------------------------------------------
# Rational roots (via Newton's method)
# ------------------------------------------------------------------------------

func sqrt*[T](n: Rational[T], iterations: int = 4): Rational[
    T] {.contractual.} =
  ## `sqrt(n)` via Newton's method. Default 4 iterations: ~9 decimal digits for
  ## int64; 5 iterations would overflow int64 for non-perfect-square inputs.
  ## Approximate (Newton iteration to `iterations`).
  body:
    if n.num == default(T): return n

    # Initial guess: sqrt(num)/sqrt(den) (integer square roots of the parts).
    let sNum = isqrt.isqrt(n.num)
    let sDen = isqrt.isqrt(n.den)

    var x = if sNum == default(T) or sDen == default(T): n
            else: initRational(sNum, sDen)

    let half = fromInt(Rational[T], 1) / fromInt(Rational[T], 2)
    for _ in 1 .. iterations:
      x = half * (x + (n / x))
    x

# ------------------------------------------------------------------------------
# Rational special functions
# ------------------------------------------------------------------------------

func factorial*[T](n: int): Rational[T] {.contractual.} =
  ## Integer factorial as a `Rational[T]` (exact for `n!` within range).
  body:
    gamma.factorial[Rational[T]](n)

func erf*[T](x: Rational[T], terms: int = 10,
    piApprox: Rational[T] = piRational[T]()): Rational[T] {.contractual.} =
  ## Error function for rationals. Takes a `pi` approximation as a `Rational`
  ## (the `Field`-bounded core has no notion of `pi`), defaulting to the
  ## module's `piRational` (the convergent `355/113`). Approximate (truncated
  ## Taylor + Newton `sqrt`).
  body:
    let sqrtWrap = proc(v: Rational[T]): Rational[T] {.noSideEffect.} = sqrt(v, 5)
    error_functions.erfTaylor(x, terms, piApprox, sqrtWrap)

func besselJ0*[T](x: Rational[T], terms: int = 10): Rational[
    T] {.contractual.} =
  ## Bessel `J0` via the series core. Approximate (truncated series).
  body:
    bessel.besselJ0(x, terms)
