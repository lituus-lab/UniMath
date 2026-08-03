# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## The Gamma function `Gamma(x)` and related integer combinatorics.
##
## Implementations:
## - `factorial(n)`: exact for non-negative integers (`n! = 1*2*...*n`,
##   `0! = 1`); returns `zero(F)` for `n < 0` (undefined).
## - `gammaStirling(x)`: leading-term Stirling asymptotic, `~1%` at `x=8`,
##   improving as `O(1/x)`. Domain `x > 0`; `x <= 0` raises `ValueError`.
## - `gammaLanczosFloat(x)`: Lanczos (g=7, n=9), `< 1e-10` relative error where
##   `Gamma` is defined. `x > 0` takes the Lanczos sum (recurrence lift for
##   `0 < x < 1`); `x < 0` non-integer uses reflection `Gamma(x) = pi /
##   (sin(pi*x)*Gamma(1-x))` (the `1-x > 0` arm terminates, no recursion);
##   `x = 0,-1,-2,...` is a simple pole -> raises `ValueError`.
## - `gammaLanczos(x, ...)`: the generic `Field` Lanczos, with injected
##   witnesses (`fromFloatFunc`, `expFunc`, `powFunc`, `sinFunc`, `piConst`).
## - `doubleFactorial(n)`, `binomial(n, k)`: integer combinatorics.
##
## Domain guards are body `raise`s, so they survive `-d:release`/`-d:danger` and
## the (absent) `ensure:` is skipped on raise. Integer construction uses the
## uniform `fromInt(F, n)` overload; the float64-to-`F` coefficient conversion in
## `gammaLanczos` keeps its `fromFloatFunc` witness (a `Transcendental` concept
## that would let us drop it is deferred), as do the transcendental witnesses.
import std/math
import contracts
import ../arithmetic

func factorial*[F: Field](n: int): F {.contractual.} =
  ## `n!` exactly for non-negative integers; `zero(F)` for `n < 0`.
  body:
    if n < 0:
      return zero(F)
    if n <= 1:
      return one(F)

    var res = one(F)
    for i in 2 .. n:
      res = res * fromInt(F, i)
    return res

func gammaStirling*[F: Field](
    x: F,
    expFunc: proc(v: F): F {.noSideEffect.},
    sqrtFunc: proc(v: F): F {.noSideEffect.},
    lnFunc: proc(v: F): F {.noSideEffect.},
    piConst: F
): F {.contractual.} =
  ## `Gamma(x) ~ sqrt(2*pi/x) * (x/e)^x` (leading term), where
  ## `(x/e)^x = exp(x*(ln(x) - 1))`. Domain `x > 0`; `x <= 0` raises
  ## `ValueError`. For `0 < x < 1` lifts via `Gamma(x) = Gamma(x+1)/x`.
  body:
    let z0 = zero(F)
    let o1 = one(F)

    if x <= z0:
      raise newException(ValueError, "gammaStirling: x <= 0 (undefined)")

    if x < o1:
      return gammaStirling(x + o1, expFunc, sqrtFunc, lnFunc, piConst) / x

    let twoPi = fromInt(F, 2) * piConst
    let sqrtTerm = sqrtFunc(twoPi / x)

    let lnXOverE = lnFunc(x) - o1
    let expTerm = expFunc(x * lnXOverE)

    return sqrtTerm * expTerm

# Lanczos coefficients for g=7, n=9 — ~15 decimal digits of accuracy.
const lanczosCoefficients*: array[9, float64] = [
  0.99999999999980993,
  676.5203681218851,
  -1259.1392167224028,
  771.32342877765313,
  -176.61502916214059,
  12.507343278686905,
  -0.13857109526572012,
  9.9843695780195716e-6,
  1.5056327351493116e-7
]

const lanczosG*: float64 = 7.0
const lanczosPi*: float64 = 3.14159265358979323846

func gammaLanczosFloat*(x: float64): float64 {.contractual.} =
  ## `Gamma(x)` via the Lanczos approximation (g=7, n=9), float64. Relative
  ## error `< 1e-10` where `Gamma` is defined. Poles at non-positive integers
  ## raise `ValueError`; `x < 0` non-integer uses reflection. No `ensure:`:
  ## `Gamma` has no zeros (only poles), but the postcondition would fire on the
  ## pole `raise` path (NimContracts checks `ensure:` even when the body raises,
  ## against the default `0.0`).
  body:
    if x <= 0.0:
      if x == round(x):
        raise newException(ValueError,
          "gammaLanczosFloat: pole at non-positive integer " & $x)
      let piX = lanczosPi * x
      return lanczosPi / (sin(piX) * gammaLanczosFloat(1.0 - x))

    if x < 1.0:
      return gammaLanczosFloat(x + 1.0) / x

    let z = x - 1.0
    var sum = lanczosCoefficients[0]
    for i in 1..8:
      sum += lanczosCoefficients[i] / (z + float64(i))
    let t = z + lanczosG + 0.5
    let sqrt2Pi = sqrt(2.0 * lanczosPi)
    result = sqrt2Pi * pow(t, z + 0.5) * exp(-t) * sum

func gammaLanczos*[F: Field](
    x: F,
    fromFloatFunc: proc(val: float64): F {.noSideEffect.},
    expFunc: proc(v: F): F {.noSideEffect.},
    powFunc: proc(b, e: F): F {.noSideEffect.},
    sinFunc: proc(v: F): F {.noSideEffect.},
    piConst: F
): F {.contractual.} =
  ## `Gamma(x)` via the Lanczos approximation (g=7, n=9), generic over any
  ## `Field` with the supplied witnesses. Domain mirrors `gammaLanczosFloat`:
  ## `x > 0` takes the Lanczos sum (recurrence lift for `0 < x < 1`); `x < 0`
  ## uses reflection; poles raise `ValueError`. `sqrt(2*pi)` is obtained as
  ## `powFunc(2*pi, 1/2)`, so no separate sqrt witness is needed.
  body:
    let z0 = zero(F)
    let o1 = one(F)

    if x <= z0:
      let oneMinusX = o1 - x
      let gammaOneMinusX = gammaLanczos(oneMinusX, fromFloatFunc,
                                        expFunc, powFunc, sinFunc, piConst)
      let sinPiX = sinFunc(piConst * x)
      if sinPiX == z0:
        raise newException(ValueError,
          "gammaLanczos: pole at non-positive integer (sin(pi*x) == 0)")
      return piConst / (sinPiX * gammaOneMinusX)

    if x < o1:
      return gammaLanczos(x + o1, fromFloatFunc,
                          expFunc, powFunc, sinFunc, piConst) / x

    let z = x - o1
    var sum = fromFloatFunc(lanczosCoefficients[0])
    for i in 1..8:
      sum = sum + fromFloatFunc(lanczosCoefficients[i]) / (z + fromInt(F, i))

    let half = fromFloatFunc(0.5)
    let t = z + fromFloatFunc(lanczosG) + half
    let sqrt2Pi = powFunc(fromInt(F, 2) * piConst, half)
    result = sqrt2Pi * powFunc(t, z + half) * expFunc(-t) * sum

func doubleFactorial*[F: Field](n: int): F {.contractual.} =
  ## `n!! = n*(n-2)*(n-4)*...*(2 or 1)`; `one(F)` for `n <= 0` by convention.
  body:
    if n <= 0:
      return one(F)

    var res = one(F)
    var i = n
    while i > 0:
      res = res * fromInt(F, i)
      i -= 2
    return res

func binomial*[F: Field](n, k: int): F {.contractual.} =
  ## `C(n,k) = n! / (k!*(n-k)!)`; `zero(F)` for `k` outside `[0, n]`.
  body:
    if k < 0 or k > n:
      return zero(F)
    if k == 0 or k == n:
      return one(F)

    let k2 = if k > n div 2: n - k else: k

    var res = one(F)
    for i in 0..<k2:
      res = res * fromInt(F, n - i)
      res = res / fromInt(F, i + 1)
    return res
