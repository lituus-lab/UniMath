# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Transcendental functions for `Complex[T]`, generic over the component.
##
## The type layer (`complex`) needs only `Field`. This module needs more: an
## ordered component carrying `sqrt`, `abs`, `ln`, `exp`, `sin`, `cos` and
## `arctan2` — i.e. a `RealField` with transcendentals. `float32`/`float64`
## (`std/math`), `BigFloat` (`float_math`), `Rational[T]` (`rational_math`) and
## `Fixed[T, FracBits]` (`math_router`) all qualify, which is why this module
## sits above them in the layer DAG rather than beside the type.
##
## `exp`, `sin`, `cos` and `atan` also come for free from the generic `Field`
## series (`expTaylor`, `sinTaylor`, `cosTaylor`, `atanTaylor` are bounded on
## `Field`, which `Complex` satisfies). Those cores stay available for a caller
## who wants a series; the entry points here are closed forms, which cost one
## real transcendental per component instead of a truncated complex series and
## hold their accuracy far from the origin.
##
## Branch cuts. `sqrt` and `ln` take the principal value, `arg(z)` in
## `(-pi, pi]`, the cut along the negative real axis. Signed zero is **not**
## honoured: `sqrt` of a negative real returns the `+i` root, so `csqrt(-1.0)`
## is `0+1i`. IEEE-754 would distinguish `-1-0i` from `-1+0i`; the exact
## backends have no signed zero, so a uniform rule beats one only half the
## components can honour.
##
## Contracts: `{.contractual.}` + `body:` only — no inline `ensure:`. These are
## approximate algorithms whose postconditions would re-invoke the contracted
## `Complex`/component operators (recursion doctrine). The precision envelope is
## verified externally against the MPC oracle (`tests/test_complex_oracle.nim`).
## Domain guards (`ln` of zero, `tan` at a pole, division by zero) are body
## paths that survive `-d:release`.
##
## Whatever reaches a `BigFloat` transcendental is a `proc`: those read
## module-level caches, which Nim's effect system counts as global state. The
## caches are immutable after module init, so nothing about the values changes
## — only what the compiler will let the signature claim.
import contracts
import std/math
import ./arithmetic
import ./complex
import ./float_math
import ./rational_math
import ./math_router
import ./roots
# `twoSquare`/`twoSum`: `lnAbs` needs |z|^2 - 1 exactly where it nears zero.
import ./eft
# `ln1pGeneric` only: `lnAbs` needs ln(1+x) for an x that may be far below the
# component's epsilon, which no backend's own `ln` provides.
import ./exponential/logarithm_generic

# ------------------------------------------------------------------------------
# Modulus, argument, polar form
# ------------------------------------------------------------------------------

func abs*[T](z: Complex[T]): T {.contractual.} =
  ## Modulus `|z|`, as a component value — so `Complex` does not satisfy
  ## `RealField` (whose `abs(x) is typeof(x)` fails here), and no generic
  ## Euclidean-norm code can mistake it for a real scalar.
  ##
  ## Scaled by the larger component rather than `sqrt(norm2(z))`: squaring
  ## overflows a bounded component well before the modulus does
  ## (`abs(complex(1e300, 1e300))` is finite, `norm2` is not). Approximate —
  ## `sqrt` is.
  body:
    mixin abs, sqrt
    let zero = fromInt(T, 0)
    let one = fromInt(T, 1)
    let a = abs(z.re)
    let b = abs(z.im)
    if a == zero: return b
    if b == zero: return a
    if b < a:
      let r = b / a
      return a * sqrt(one + r * r)
    let r = a / b
    return b * sqrt(one + r * r)

proc arg*[T](z: Complex[T]): T {.contractual.} =
  ## Argument `arg(z)` in `(-pi, pi]` via the component's `arctan2`. `arg(0)`
  ## is `arctan2(0, 0)`, which every backend here defines as `0`. Approximate.
  body:
    mixin arctan2
    arctan2(z.im, z.re)

proc piOf[T](): T {.inline.} =
  ## `pi` for the component, as `arctan2(0, -1)` — the principal argument of
  ## `-1`. Derives the constant from the same `arctan2` the branch cut is
  ## defined by, so `ln` of a negative real lands exactly on the cut whatever
  ## the backend's own pi constant rounds to. Non-contracted private helper.
  mixin arctan2
  arctan2(fromInt(T, 0), -fromInt(T, 1))

proc polar*[T](z: Complex[T]): (T, T) {.contractual.} =
  ## `(modulus, argument)`. Approximate.
  body:
    (abs(z), arg(z))

proc rect*[T](r, theta: T): Complex[T] {.contractual.} =
  ## Polar to Cartesian: `r * (cos theta + i sin theta)`. Approximate.
  body:
    mixin sin, cos
    complex(r * cos(theta), r * sin(theta))

# ------------------------------------------------------------------------------
# Square root, and the promotion of a negative real
# ------------------------------------------------------------------------------

func sqrt*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## Principal square root. Uses the half-angle identity rather than
  ## `rect(sqrt(abs z), arg(z)/2)`: the form below needs one real `sqrt` and no
  ## trigonometry, and each branch adds the two same-signed quantities so no
  ## cancellation is possible. Approximate.
  body:
    mixin abs, sqrt
    let zero = fromInt(T, 0)
    let two = fromInt(T, 2)
    if z.isZero:
      return complex(zero, zero)
    let m = abs(z)
    if not (z.re < zero):
      # m + re >= |re| + re >= 0, and is zero only for z == 0 (excluded).
      let t = sqrt((m + z.re) / two)
      return complex(t, z.im / (two * t))
    # m - re > 0 whenever re < 0, so the divisor below is never zero.
    let u = sqrt((m - z.re) / two)
    let re = abs(z.im) / (two * u)
    return complex(re, if z.im < zero: -u else: u)

func csqrt*[T](x: T): Complex[T] {.contractual.} =
  ## Square root of a **real**, returned as a complex: `csqrt(-1.0)` is
  ## `0+1i` where the real `sqrt` has no answer and raises. A separate name
  ## rather than a wider `sqrt`, because the return type is fixed at compile
  ## time and `RealField` requires `sqrt(x) is typeof(x)`. Approximate.
  body:
    mixin sqrt
    let zero = fromInt(T, 0)
    if x < zero:
      return complex(zero, sqrt(-x))
    complex(sqrt(x), zero)

# ------------------------------------------------------------------------------
# Exponential and logarithm
# ------------------------------------------------------------------------------

proc exp*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## `exp(z) = exp(re) * (cos(im) + i sin(im))`. Approximate.
  body:
    mixin exp, sin, cos
    let e = exp(z.re)
    complex(e * cos(z.im), e * sin(z.im))

const LnAbsMinTerms = 20
  ## Floor on the series length for the `ln1pGeneric` call in `lnAbs`. The
  ## argument is bounded so that `u = s / (2 + s)` stays within 1/3, reached at
  ## `s == -1/2` — that is, at `|z|^2 == 1/2`, where the first dropped term is
  ## `2 * (1/3)^41 / 41`, some 69 bits down. Far below a `float64` ulp, and
  ## past what any other bounded component here resolves.

proc lnAbsTerms[T](s: T): int {.inline.} =
  ## Series length that carries the component's own resolution rather than the
  ## fixed 69 bits the floor buys. Driving `2 * |u|^(2n+1) / (2n+1)` below
  ## `2^-p` at the worst case `|u| = 1/3` needs `n >= p / (2 * log2 3)`, i.e.
  ## roughly `p / 3`.
  ##
  ## Only `BigFloat` carries a `p` that varies, and it carries it as the width
  ## of the value in hand — the same notion `float_math` budgets its own series
  ## by. Measuring the series argument rather than `z` keeps the two in step: a
  ## component holding four bits gets a four-bit answer from either.
  when compiles(bitLength(s.mantissa)):
    max(LnAbsMinTerms, bitLength(s.mantissa) div 3 + 4)
  else:
    LnAbsMinTerms

func unitResidual[T](a, b: T): T {.inline.} =
  ## `a*a + b*b - 1`, kept accurate where that difference is near zero.
  ##
  ## The obvious rewrite `(a-1)*(a+1) + b*b` only helps when `a` alone sits
  ## near 1. On the unit circle at 40 degrees both components are near 0.7 and
  ## it is the two squares that cancel against each other, each carrying its
  ## own rounding into a result some twelve orders of magnitude smaller.
  ##
  ## Where the component supports the error-free transforms, both squares and
  ## their sum are therefore taken exactly and the discarded low parts are
  ## added back. `s1 - 1` is exact by Sterbenz whenever `s1` is in `[1/2, 2]`,
  ## which is the only range where the caller uses this branch, so nothing is
  ## lost on the way out. Elsewhere -- `BigFloat`, `Rational`, `Fixed`, none of
  ## which have `twoSquare` -- the algebraic form is used; the exact backends
  ## do not round at all, and `BigFloat` has the spare bits to absorb it.
  mixin twoSquare, twoSum
  let one = fromInt(T, 1)
  when compiles(twoSquare(a)):
    let (pa, ea) = twoSquare(a)
    let (pb, eb) = twoSquare(b)
    let (s1, es) = twoSum(pa, pb)
    ((s1 - one) + es) + (ea + eb)
  else:
    (a - one) * (a + one) + b * b

proc lnAbs[T](z: Complex[T]): T =
  ## `ln|z|`, never by forming `|z|` and taking its logarithm.
  ##
  ## A `proc`, not a `func`, for the reason the module header gives: the
  ## `BigFloat` `ln` it delegates to reads module-level caches.
  ##
  ## Near the unit circle `ln|z|` tends to zero while `|z|` tends to one, so
  ## `ln(abs(z))` loses a digit for every power of ten between them: on
  ## `float64` the real part came out 4.6e-5 wrong at `|z| - 1 == 1e-12`. The
  ## first branch instead hands `|z|^2 - 1` straight to `ln1p` as the small
  ## quantity it is, and computes it without cancellation.
  ##
  ## The second branch drops the square root as well: `ln(a) + ln1p((b/a)^2)/2`
  ## has an exactly-zero second term when `b` is zero, where `ln(sqrt(a*a +
  ## b*b))` would pay for a squaring and a root first.
  ##
  ## Non-contracted private helper (`ensure:` may only call non-contracted
  ## procs). Assumes `z != 0`; `ln` checks that.
  mixin abs, ln
  let one = fromInt(T, 1)
  let two = fromInt(T, 2)
  let half = one / two
  var a = abs(z.re)
  var b = abs(z.im)
  if a < b:
    swap(a, b)
  # `b <= a` gives `a^2 <= |z|^2 <= 2*a^2`, so `|z|` can only approach 1 while
  # `a` is in `[1/sqrt(2), 1]`. Testing `[1/2, 2]` covers that with room to
  # spare and keeps `unitResidual` away from the squaring overflow that
  # `a == 1e300` would otherwise cause.
  if half <= a and a <= two:
    let s = unitResidual(a, b)
    if -half <= s and s <= half:
      return half * ln1pGeneric(s, lnAbsTerms(s))
  # Here the result is carried by `ln(a)` and the second term is a bounded
  # correction, so its own relative error cannot reach the answer: the
  # component's plain `ln` serves, and costs one call instead of a series.
  let r = b / a
  return ln(a) + half * ln(one + r * r)

proc ln*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## Principal logarithm `ln|z| + i arg(z)`, accurate componentwise: the real
  ## part goes through `lnAbs`, which does not cancel against the unit circle.
  ## Raises `ValueError` on zero (body path, survives release) — the real `ln`
  ## does the same, and no branch of the complex log is finite there.
  ## Approximate.
  body:
    if z.isZero:
      raise newException(ValueError, "ln: complex zero has no logarithm")
    complex(lnAbs(z), arg(z))

proc cln*[T](x: T): Complex[T] {.contractual.} =
  ## Logarithm of a **real**, returned as a complex: `cln(-1.0)` is `0 + pi*i`
  ## where the real `ln` has no answer and raises. Zero still raises, through
  ## the component's own `ln`. Approximate.
  body:
    mixin ln
    let zero = fromInt(T, 0)
    if x < zero:
      return complex(ln(-x), piOf[T]())
    complex(ln(x), zero)

# ------------------------------------------------------------------------------
# Trigonometric and hyperbolic
# ------------------------------------------------------------------------------

proc coshSinh[T](x: T): (T, T) {.inline.} =
  ## `(cosh x, sinh x)` for the component. Prefers the component's own
  ## `sinh`/`cosh` where they exist, and falls back to `exp` otherwise.
  ##
  ## The fallback is only safe for a component with precision to spare.
  ## `(e - 1/e) / 2` cancels catastrophically as `x` approaches zero: both
  ## terms tend to 1 while their difference tends to `2x`, so the relative
  ## error grows like `1/x`. Measured against MPC on `float64`, that reached
  ## 400 ulp near the origin. `float64` (`std/math`), `Fixed` (`math_router`)
  ## and `Rational` (`rational_math`) all ship `sinh`/`cosh`, so only
  ## `BigFloat` takes the fallback, where 256 bits absorb the lost digits well
  ## below what a `float64` result can see. Non-contracted private helper.
  mixin exp, sinh, cosh
  when compiles((sinh(x), cosh(x))):
    (cosh(x), sinh(x))
  else:
    let two = fromInt(T, 2)
    let e = exp(x)
    let ei = fromInt(T, 1) / e
    ((e + ei) / two, (e - ei) / two)

proc sin*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## `sin(a+bi) = sin a cosh b + i cos a sinh b`. Approximate.
  body:
    mixin sin, cos
    let (ch, sh) = coshSinh(z.im)
    complex(sin(z.re) * ch, cos(z.re) * sh)

proc cos*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## `cos(a+bi) = cos a cosh b - i sin a sinh b`. Approximate.
  body:
    mixin sin, cos
    let (ch, sh) = coshSinh(z.im)
    complex(cos(z.re) * ch, -(sin(z.re) * sh))

proc tan*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## `sin(z) / cos(z)`. A pole raises `DivByZeroDefect` through the complex `/`
  ## (body path, survives release). Approximate.
  body:
    sin(z) / cos(z)

proc sinh*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## `sinh(a+bi) = sinh a cos b + i cosh a sin b`. Approximate.
  body:
    mixin sin, cos
    let (ch, sh) = coshSinh(z.re)
    complex(sh * cos(z.im), ch * sin(z.im))

proc cosh*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## `cosh(a+bi) = cosh a cos b + i sinh a sin b`. Approximate.
  body:
    mixin sin, cos
    let (ch, sh) = coshSinh(z.re)
    complex(ch * cos(z.im), sh * sin(z.im))

proc tanh*[T](z: Complex[T]): Complex[T] {.contractual.} =
  ## `sinh(z) / cosh(z)`. A pole raises `DivByZeroDefect`. Approximate.
  body:
    sinh(z) / cosh(z)

# ------------------------------------------------------------------------------
# Powers
# ------------------------------------------------------------------------------

func pow*[T](z: Complex[T], n: int): Complex[T] {.contractual.} =
  ## Integer power by binary exponentiation — **exact** on the exact backends,
  ## since it never leaves the ring. A negative `n` inverts first, so `z == 0`
  ## raises `DivByZeroDefect`; `pow(z, 0)` is `1` for every `z`, zero included.
  body:
    if n == 0:
      return fromInt(Complex[T], 1)
    var base = if n < 0: inv(z) else: z
    var k = if n < 0: -n else: n
    var acc = fromInt(Complex[T], 1)
    while k > 0:
      if (k and 1) == 1:
        acc = acc * base
      base = base * base
      k = k shr 1
    acc

proc pow*[T](z, w: Complex[T]): Complex[T] {.contractual.} =
  ## Principal `z^w = exp(w * ln z)`. `z == 0` raises `ValueError` through
  ## `ln` — including `0^0`, which the integer overload answers as `1`.
  ## Approximate.
  body:
    exp(w * ln(z))
