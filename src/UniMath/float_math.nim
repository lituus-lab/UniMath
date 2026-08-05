# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Transcendental functions for `BigFloat`, range-reduced over the generic
## Taylor/Newton/Machin cores.
##
## The generic primitives (`sinTaylor`/`cosTaylor`/`atanTaylor` in
## `trigonometry`, `expTaylor`/`lnGeneric` in `exponential`) are exact but
## converge usefully only for small arguments. `sqrt` uses an inline
## reciprocal-Newton (multiply-only) rather than the generic core. This
## module wraps them with range reduction (from `reduction`): `sin`/`cos` fold
## the argument into `[-pi/4, pi/4]` via the octant identities; `exp` scales by
## `2^k` and squares back; `ln` brings the mantissa into `[sqrt(1/2), sqrt(2)]`
## so the atanh series converges fast. `tan`/`pow`/`arctan`/`arctan2`/`sqrt`
## complete the surface.
##
## Contracts: `{.contractual.}` + `body:` only — no inline `ensure:`. These are
## approximate algorithms whose postconditions would re-evaluate a contracted
## primitive or a `BigFloat` comparison delegating to the contracted `cmp`
## (recursion doctrine). The precision envelope is documented per-proc and
## verified externally against the MPFR oracle. Domain guards (`ln`/`pow`/`tan`
## singularities) are body `raise`s that survive `-d:release`. The cache-reading
## procs (`sin`/`cos`/`exp`/`ln`/`tan`/`pow`) are `proc` (not `func`): reading
## the module-level octant/`ln(2)` caches is flagged as global-state access by
## Nim's strict effect system, so they cannot carry `.noSideEffect`. The caches
## are immutable after module init — a purity annotation only.
import contracts
import std/math
import ./float
import ./arithmetic
import ./constants
import ./reduction
import ./trigonometry
import ./exponential

const
  sqrt2F64* = 1.4142135623730951 ## sqrt(2) as a float64 (ln mantissa-halve threshold)
  tanPi8F64* = 0.4142135623730951 ## tan(pi/8) = sqrt(2)-1 (arctan reduce threshold)

# Octant-fold caches and ln(2), built once at module load from the cached pi
# (`piConst`) and the generic `lnGeneric`. `arctan`/`arctan2` are `func`s and
# cannot read these (or `piConst`, a `proc`); they recompute pi via
# `getPiBigFloat` (a pure `func`) instead.
let halfPiCache: BigFloat = scaleByPow2(piConst(), -1)
let quarterPiCache: BigFloat = scaleByPow2(piConst(), -2)
let threeQuarterPiCache: BigFloat = halfPiCache + quarterPiCache

# ln(2) at 256-bit precision via the atanh series (x = 1/3, the slow case, 200
# terms for ~256 correct bits). Built directly from `lnGeneric` (not
# recursively via `ln`, which needs ln(2) — circular).
let ln2Cache: BigFloat = lnGeneric(initBigFloat(2.0, 256), 200)

proc sin*(x: BigFloat, terms: int = 20): BigFloat {.contractual.} =
  ## `sin(x)` with argument reduction: stage 1 reduces to `[-pi, pi]` (skipped
  ## when `|x| <= pi`), stage 2 folds `|r|` into `[0, pi/4]` via the four octant
  ## identities, restoring the sign of `r` (sin is odd). Approximate.
  body:
    let pi = piConst()
    let r = if x <= pi and x >= -pi: x else: reduceModTwoPi(x)
    let a = abs(r)
    let neg = r.sign

    if a <= quarterPiCache:
      let s = sinTaylor(a, terms)
      return if neg: -s else: s
    elif a <= halfPiCache:
      let u = halfPiCache - a # u in [0, pi/4]; sin(a) = cos(pi/2 - a)
      let s = cosTaylor(u, terms)
      return if neg: -s else: s
    elif a <= threeQuarterPiCache:
      let u = a - halfPiCache # u in (0, pi/4]; sin(a) = cos(a - pi/2)
      let s = cosTaylor(u, terms)
      return if neg: -s else: s
    elif a <= pi:
      let u = pi - a # u in [0, pi/4); sin(pi - u) = sin(u)
      let s = sinTaylor(u, terms)
      return if neg: -s else: s
    else:
      # Rounding spill: r = pi + eps (a few ulp past pi from stage 1).
      # sin(pi + u) = -sin(u); combined with the sign: -sign·sin(u).
      let u = a - pi
      let s = sinTaylor(u, terms)
      return if neg: s else: -s

proc cos*(x: BigFloat, terms: int = 20): BigFloat {.contractual.} =
  ## `cos(x)` with argument reduction (mirrors `sin`). Approximate.
  body:
    let pi = piConst()
    let r = if x <= pi and x >= -pi: x else: reduceModTwoPi(x)
    let a = abs(r) # cos is even

    if a <= quarterPiCache:
      cosTaylor(a, terms)
    elif a <= halfPiCache:
      let u = halfPiCache - a # cos(pi/2 - u) = sin(u)
      sinTaylor(u, terms)
    elif a <= threeQuarterPiCache:
      let u = a - halfPiCache # cos(pi/2 + u) = -sin(u)
      -sinTaylor(u, terms)
    elif a <= pi:
      let u = pi - a # cos(pi - u) = -cos(u)
      -cosTaylor(u, terms)
    else:
      # Rounding spill: cos(pi + u) = -cos(u).
      let u = a - pi
      -cosTaylor(u, terms)

proc exp*(x: BigFloat, terms: int = 30): BigFloat {.contractual.} =
  ## `exp(x)` by scaling-and-squaring: `exp(x) = exp(x/2^k)^(2^k)`, `k` chosen
  ## so `|x/2^k| <= 1/2`. The raw Taylor at `|x| ~ 700` destroys all precision
  ## (leading term `~1e304`); scaling brings the argument below `1/2` (fast
  ## convergence) and `k` squarings recover the value. `k = 0` when `|x| <= 1/2`.
  ## Approximate.
  body:
    let one = one(BigFloat)
    if x.isZero: return one

    # k = max(0, exponent + bitLength(mantissa) + 1) guarantees |x|/2^k < 1/2.
    let bl = bitLength(x.mantissa)
    var k = int(x.exponent) + bl + 1
    if k < 0: k = 0

    let y = scaleByPow2(x, -k) # exact: exponent only, |y| <= 1/2
    result = expTaylor(y, terms)
    for _ in 1 .. k:
      result = result * result # recover the 2^k scaling

proc ln*(x: BigFloat, terms: int = 30): BigFloat {.contractual.} =
  ## `ln(x)` with argument reduction: `ln(z) = ln(m) + E·ln(2)` with `m` brought
  ## into `[sqrt(1/2), sqrt(2)]` so the atanh series converges fast
  ## (`|(m-1)/(m+1)| <= 0.17`, ~5 bits/term). Raises `ValueError` for `x <= 0`
  ## (body `raise`, survives release). Approximate.
  body:
    if x.isZero:
      raise newException(ValueError, "ln: input is zero (real log undefined)")
    if x.sign:
      raise newException(ValueError, "ln: input is negative (real log undefined)")

    # z = mantissa · 2^exponent, mantissa normalized (top bit set) => mantissa in
    # [2^(B-1), 2^B) with B = bitLength(mantissa). Decompose z = m · 2^E with
    # m = mantissa / 2^(B-1) in [1, 2) and E = exponent + B - 1.
    let B = bitLength(x.mantissa)
    var m = BigFloat(sign: false, exponent: -int64(B - 1),
                     mantissa: x.mantissa) # m in [1, 2)
    var E = int(x.exponent) + B - 1

    # Halve m past sqrt(2) => m in [sqrt(1/2), sqrt(2)]; the series arg <= 0.17.
    if toFloat64(m) > sqrt2F64: # sqrt(2)
      m = scaleByPow2(m, -1) # exact: exponent only
      E += 1

    let lnM = lnGeneric(m, terms) # ln(m), fast series
    result = lnM + fromInt(BigFloat, E) * ln2Cache # E·ln(2); E is exact

func sqrt*(x: BigFloat, iterations: int = 15): BigFloat {.contractual.} =
  ## `sqrt(x)` for `BigFloat` via Newton-Raphson on the reciprocal square root:
  ## `y_{k+1} = y_k * (1.5 - 0.5 * g * y_k^2)` (multiply-only — no per-iteration
  ## division), then `sqrt = g * y * 2^s`. The argument is reduced to `g in
  ## [1, 4)` with an even binary exponent so the float64 seed `1/sqrt(g)` stays
  ## in range; each step doubles the correct bits, so the per-step precision is
  ## doubled (53 -> 106 -> 212 -> 256) and early steps run at lower width. Newton
  ## is self-correcting, so rounding the iterates does not accumulate. The result
  ## is faithful (<= 1 ulp at 256 bits), verified against the MPFR oracle.
  ## `iterations` caps the Newton step count (the schedule self-limits at ~4).
  ## Public-domain algorithm: `sqrt(x) = x * (1/sqrt(x))`.
  body:
    if isZero(x):
      return x
    if x.sign:
      raise newException(ValueError, "sqrt: input is negative (sqrt undefined)")
    const p = 256
    # value = M * 2^E, M in [2^(p-1), 2^p). Split E = 2*q + r (r in {0,1}) so
    # sqrt(value) = sqrt(M * 2^r) * 2^q, then reduce M*2^r to g in [1,4) with an
    # even bit length e: sqrt(M*2^r) = sqrt(g) * 2^(e/2). The reduction is by
    # powers of two only, so it is exact.
    let M = x.mantissa
    let E = x.exponent
    let r = int64(((E mod 2) + 2) mod 2)
    let q = (E - r) div 2
    let L = bitLength(M) + int(r)
    let e = if (L - 1) mod 2 == 0: L - 1 else: L - 2
    var g = BigFloat(sign: false, exponent: int64(r) - int64(e), mantissa: M)
    g.normalize(p)
    # float64 seed for 1/sqrt(g): ~53 correct bits, g in [1,4) so no overflow.
    const seedPrec = 64
    var y = initBigFloat(1.0 / sqrt(toFloat64(g)), seedPrec)
    let onePointFive = initBigFloat(1.5, p)
    # Precision-doubling Newton, then a final full-width pass for rounding.
    var steps = 0
    var pk = 53
    while pk < p and steps < iterations:
      pk = min(p, pk * 2)
      let y2 = mulRounded(y, y, pk, rmNearest)
      let t = mulRounded(g, y2, pk, rmNearest)
      let u = subRounded(onePointFive, scaleByPow2(t, -1), pk, rmNearest)
      y = mulRounded(y, u, pk, rmNearest)
      inc steps
    if steps < iterations:
      let y2 = mulRounded(y, y, p, rmNearest)
      let t = mulRounded(g, y2, p, rmNearest)
      let u = subRounded(onePointFive, scaleByPow2(t, -1), p, rmNearest)
      y = mulRounded(y, u, p, rmNearest)
    # sqrt(g) = g * y, then scale by 2^(e/2 + q) to undo the reduction.
    result = mulRounded(g, y, p, rmNearest)
    result.exponent += int64(e div 2) + q
    result.normalize(p)

func getPiBigFloat*(): BigFloat {.contractual, noSideEffect.} =
  ## `pi` as a 256-bit `BigFloat` (Machin formula) — a pure recomputation for
  ## the `func` transcendentals (`arctan`/`arctan2`) that cannot read the cached
  ## `piConst` (a `proc`). A float64 literal would carry only ~53 correct bits.
  body:
    piBigFloat(256)

proc tan*(x: BigFloat, terms: int = 20): BigFloat {.contractual.} =
  ## `tan(x) = sin(x)/cos(x)`. Raises `DivByZeroDefect` when `cos(x)` is zero at
  ## the current precision (neighborhood of `pi/2 + k·pi`). Body `raise`
  ## (survives release). Approximate.
  body:
    let c = cos(x, terms)
    if isZero(c):
      raise newException(DivByZeroDefect, "tan: cos(x) is zero (singularity)")
    sin(x, terms) / c

func pow*(x: BigFloat, n: int): BigFloat {.contractual.} =
  ## `x^n`, integer exponent — fast exponentiation (repeated squaring). `n < 0`:
  ## `1 / x^(-n)` (raises `DivByZeroDefect` when `x` is zero). The mults are the
  ## correctly-rounded BigFloat `*`; the result is approximate to the working
  ## precision. Body `raise`s (n<0, x=0) survive release.
  body:
    let one = one(BigFloat)
    if n == 0:
      return one
    if n < 0:
      return one / pow(x, -n)
    var base = x
    var e = n
    result = one
    while e > 0:
      if (e and 1) == 1:
        result = result * base
      base = base * base
      e = e shr 1

proc pow*(x, y: BigFloat, terms: int = 30): BigFloat {.contractual.} =
  ## `x^y = exp(y·ln(x))` for `x > 0` (raises `ValueError` otherwise). Body
  ## `raise` (survives release). Approximate.
  body:
    let zero = zero(BigFloat)
    if not (x > zero):
      raise newException(ValueError, "pow: base <= 0 (non-integer exponent)")
    exp(y * ln(x, terms), terms)

func arctan*(x: BigFloat, terms: int = 30): BigFloat {.contractual.} =
  ## `arctan(x)` by Taylor series with argument reduction:
  ## - `|x| > 1`: `atan(x) = +/-(pi/2 - atan(1/|x|))`
  ## - `tan(pi/8) < |x| <= 1`: `atan(x) = +/-(pi/4 + atan((|x|-1)/(|x|+1)))`
  ##   (the raw series at `|x| ~ 1` is the Leibniz series, ~1/n convergence;
  ##    the reduction brings the argument below 0.415, ~2.5 bits/term)
  ## - otherwise: direct series.
  ## Approximate; verified vs MPFR.
  body:
    let one = one(BigFloat)
    let zero = zero(BigFloat)
    let ax = abs(x)
    if ax > one:
      let halfPi = getPiBigFloat() / fromInt(BigFloat, 2)
      let res = halfPi - arctan(one / ax, terms)
      return if x < zero: -res else: res
    if toFloat64(ax) > tanPi8F64: # tan(pi/8)
      let quarterPi = getPiBigFloat() / fromInt(BigFloat, 4)
      let reduced = (ax - one) / (ax + one) # in (-0.415, 0]
      let res = quarterPi + atanTaylor(reduced, terms)
      return if x < zero: -res else: res
    return atanTaylor(x, terms)

func arctan2*(y, x: BigFloat, terms: int = 30): BigFloat {.contractual.} =
  ## `arctan2(y, x)` via `arctan` with quadrant dispatch. The underlying
  ## `arctan` is approximate (see above). Approximate; verified vs MPFR.
  body:
    let zero = zero(BigFloat)
    # `getPiBigFloat` is a full 256-bit Machin evaluation on every call, not a
    # cached constant, so it stays out of the branch that never reads it.
    if x > zero:
      return arctan(y / x, terms)
    elif x < zero:
      let pi = getPiBigFloat()
      if y >= zero: return arctan(y / x, terms) + pi
      else: return arctan(y / x, terms) - pi
    else: # x == 0
      if y > zero: return getPiBigFloat() / fromInt(BigFloat, 2)
      elif y < zero: return -(getPiBigFloat() / fromInt(BigFloat, 2))
      else: return zero
