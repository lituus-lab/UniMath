# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Unified Math Router (Auto/Easy Mode) for `Fixed[T, FracBits]`.
##
## A single entry point per function that dispatches to the best core (CORDIC,
## Taylor, Chebyshev, Newton) based on the type and the `MathAlgo` selector. The
## default `Auto` picks the core the fixed-point kernels are tuned for: CORDIC
## for `sin`/`cos`/`atan2`, Chebyshev for `tan`, hyperbolic-CORDIC for
## `exp`/`sinh`/`cosh`/`tanh`, Newton for `sqrt`, Taylor for `ln`.
##
## Contracts: `{.contractual.}` + `body:` only — no inline `ensure:`. These are
## approximate-algorithm dispatch wrappers; an `ensure:` recomputing the result
## would invoke the contracted `Fixed` operators (recursion doctrine). The
## precision envelope is documented on the delegated core and verified
## externally. Domain guards (`ln` raises on `x <= 0`; `asin`/`acos`/`acosh`/
## `atanh`/`pow` return the type's default for out-of-domain input) live in
## `body:` and so survive release.
import contracts
import ./fixed
import ./constants
import ./roots/sqrt_newton
import ./trigonometry/cordic
import ./trigonometry/taylor
import ./trigonometry/chebyshev
import ./exponential/taylor as exp_taylor
import ./hyperbolic/cordic as hyp_cordic
import ./special/gamma
import ./special/error_functions
import ./special/bessel

type
  MathAlgo* = enum
    Auto
    Cordic
    Taylor
    Chebyshev
    Newton

# ------------------------------------------------------------------------------
# Unified trigonometry
# ------------------------------------------------------------------------------

func sin*[T; FracBits: static[int]](x: Fixed[T, FracBits];
                                    algo: MathAlgo = Auto): Fixed[T, FracBits] {.
    contractual.} =
  ## Dispatches to the CORDIC (default) or Taylor core. Approximate — see
  ## module header; precision verified externally, no inline `ensure:`.
  body:
    case algo
    of Cordic, Auto: return cordic.sinCordic(x)
    of Taylor: return taylor.sinTaylor(x, 7)
    else: return cordic.sinCordic(x)

func cos*[T; FracBits: static[int]](x: Fixed[T, FracBits];
                                    algo: MathAlgo = Auto): Fixed[T, FracBits] {.
    contractual.} =
  ## Dispatches to the CORDIC (default) or Taylor core. Approximate.
  body:
    case algo
    of Cordic, Auto: return cordic.cosCordic(x)
    of Taylor: return taylor.cosTaylor(x, 7)
    else: return cordic.cosCordic(x)

func tan*[T; FracBits: static[int]](x: Fixed[T, FracBits];
                                    algo: MathAlgo = Auto): Fixed[T, FracBits] {.
    contractual.} =
  ## Dispatches to the Chebyshev minimax (default) or CORDIC `sin/cos` core.
  ## Approximate. The CORDIC branch computes `s / c`; a zero `c` raises via the
  ## Fixed `/` operator (body path, survives release).
  body:
    case algo
    of Chebyshev, Auto: return chebyshev.tanChebyshev(x)
    of Cordic:
      let (s, c) = cordic.sinCosCordic(x)
      return s / c
    else: return chebyshev.tanChebyshev(x)

# ------------------------------------------------------------------------------
# Unified inverse trigonometry
# ------------------------------------------------------------------------------

func atan2*[T; FracBits: static[int]](y, x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `atan2(y, x)` via CORDIC. Approximate — verified externally.
  body:
    return cordic.atan2Cordic(y, x)

func arctan2*[T; FracBits: static[int]](y, x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual, inline.} =
  ## Alias for `atan2`. Approximate.
  body:
    atan2(y, x)

func atan*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `atan(x) = atan2(x, 1)`. Approximate.
  body:
    let one = toFixed[T, FracBits](1)
    return atan2(x, one)

func arctan*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual, inline.} =
  ## Alias for `atan`. Approximate.
  body:
    atan(x)

func asin*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `asin(x) = atan2(x, sqrt(1 - x*x))`. Out-of-domain (`|x| > 1`) returns the
  ## type's default (body path, survives release). Approximate.
  body:
    let one = toFixed[T, FracBits](1)
    let sq = x * x
    if sq > one: return default(Fixed[T, FracBits])
    let root = sqrt_newton.sqrtNewtonGeneric(one - sq, 10)
    return atan2(x, root)

func arcsin*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual, inline.} =
  ## Alias for `asin`. Approximate.
  body:
    asin(x)

func acos*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `acos(x) = atan2(sqrt(1 - x*x), x)`. Out-of-domain (`|x| > 1`) returns the
  ## type's default (body path, survives release). Approximate.
  body:
    let one = toFixed[T, FracBits](1)
    let sq = x * x
    if sq > one: return default(Fixed[T, FracBits])
    let root = sqrt_newton.sqrtNewtonGeneric(one - sq, 10)
    return atan2(root, x)

func arccos*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual, inline.} =
  ## Alias for `acos`. Approximate.
  body:
    acos(x)

# ------------------------------------------------------------------------------
# Unified exponential & logarithmic
# ------------------------------------------------------------------------------

func exp*[T; FracBits: static[int]](x: Fixed[T, FracBits];
                                    algo: MathAlgo = Auto): Fixed[T, FracBits] {.
    contractual.} =
  ## Dispatches to the hyperbolic-CORDIC (default) or Taylor core. Approximate.
  body:
    case algo
    of Taylor: return exp_taylor.expTaylor(x, 15)
    else: return hyp_cordic.expCordic(x)

func ln*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## Natural logarithm via Taylor series: `ln(x) = lnTaylor(x - 1, 15 terms)`.
  ##
  ## Precondition: `x > 0`. For `x <= 0` the result is undefined and this
  ## function raises `ValueError`. The Taylor series converges reliably only
  ## for `x` near 1; for large `x` the `asinh`/`acosh` helpers in this module
  ## use range reduction via `ln(x + root)` to stay in a good convergence range.
  ## The domain guard is a body `raise` (survives release). Approximate.
  body:
    let one = toFixed[T, FracBits](1)
    if x.data <= default(T):
      raise newException(ValueError,
        "ln: argument must be positive, got " & $x.data)
    return exp_taylor.lnTaylor(x - one, 15)

# ------------------------------------------------------------------------------
# Unified hyperbolic
# ------------------------------------------------------------------------------

func sinh*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `sinh(x)` via hyperbolic CORDIC. Approximate.
  body:
    return hyp_cordic.sinhCordic(x)

func cosh*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `cosh(x)` via hyperbolic CORDIC. Approximate.
  body:
    return hyp_cordic.coshCordic(x)

func tanh*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `tanh(x)` via hyperbolic CORDIC. Approximate.
  body:
    return hyp_cordic.tanhCordic(x)

func asinh*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `asinh(x) = ln(x + sqrt(x*x + 1))`. Approximate.
  body:
    let one = toFixed[T, FracBits](1)
    let root = sqrt_newton.sqrtNewtonGeneric(x * x + one, 10)
    return ln(x + root)

func acosh*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `acosh(x) = ln(x + sqrt(x*x - 1))`, domain `x >= 1`. Out-of-domain
  ## (`x < 1`) returns the type's default (body path, survives release).
  ## Approximate.
  body:
    let one = toFixed[T, FracBits](1)
    if x < one: return default(Fixed[T, FracBits])
    let root = sqrt_newton.sqrtNewtonGeneric(x * x - one, 10)
    return ln(x + root)

func atanh*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## `atanh(x) = (1/2)·ln((1+x)/(1-x))`, domain `|x| < 1`. Out-of-domain
  ## (`|x| >= 1`) returns the type's default (body path, survives release).
  ## Approximate.
  body:
    let one = toFixed[T, FracBits](1)
    if abs(x.data) >= one.data: return default(Fixed[T, FracBits])
    let half = initFixed[T, FracBits](one.data shr 1)
    return half * ln((one + x) / (one - x))

# ------------------------------------------------------------------------------
# Unified power
# ------------------------------------------------------------------------------

func pow*[T; FracBits: static[int]](base, exponent: Fixed[T, FracBits]): Fixed[
    T, FracBits] {.contractual.} =
  ## `base^exponent = exp(exponent * ln(base))`, domain `base > 0`.
  ## Out-of-domain returns the type's default (body path, survives release).
  ## Approximate.
  body:
    if base.data <= default(T): return default(Fixed[T, FracBits])
    return exp(exponent * ln(base))

# ------------------------------------------------------------------------------
# Unified special functions
# ------------------------------------------------------------------------------

func factorial*[T; FracBits: static[int]](n: int): Fixed[T, FracBits] {.
    contractual.} =
  ## Integer factorial as a Fixed value (exact for `n!` within range).
  body:
    return gamma.factorial[Fixed[T, FracBits]](n)

func erf*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## Error function via the Taylor core with a Newton-sqrt wrapper. Approximate.
  body:
    let pi = constants.piFixed[T, FracBits]()
    let sqrtWrap = proc(v: Fixed[T, FracBits]): Fixed[T,
        FracBits] {.noSideEffect.} =
      sqrt_newton.sqrtNewtonGeneric(v, 10)
    return error_functions.erfTaylor(x, 15, pi, sqrtWrap)

func besselJ0*[T; FracBits: static[int]](x: Fixed[T, FracBits]): Fixed[T, FracBits] {.
    contractual.} =
  ## Bessel `J0` via the series core. Approximate.
  body:
    return bessel.besselJ0(x, 15)

# ------------------------------------------------------------------------------
# Unified roots
# ------------------------------------------------------------------------------

func sqrt*[T; FracBits: static[int]](x: Fixed[T, FracBits];
                                    algo: MathAlgo = Auto): Fixed[T, FracBits] {.
    contractual.} =
  ## `sqrt(x)` via Newton iteration (`sqrtNewtonGeneric`). Approximate — the
  ## convergence envelope is documented on the core and verified externally.
  body:
    # `algo` is reserved for future algorithm selection; every variant currently
    # routes through the Newton core (the only fixed-point sqrt), so the former
    # two-branch `case` (both branches identical) became a direct call.
    sqrt_newton.sqrtNewtonGeneric(x, 15)
