# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Greatest common divisor and least common multiple for any integer-like `T`
## supporting `mod`, `<`, `-`, `==` (built-in integers and `BigInt`). The
## Euclidean loop uses only `mod`, so it never negates `MinInt`; the sign is
## normalized on the result, where negating `MinInt` raises `OverflowDefect`
## under a forced `overflowChecks` push (a no-op for `BigInt`, whose `-` is a
## user proc). Bodies only — no inline `ensure:`: a divisibility postcondition
## would call `T`'s contracted `cmp`/`divMod` from an ensure (recursion
## doctrine); the identities are exercised by the rational tests.
##
## `BigInt` gets its own overload: the generic loop's `mod` is a multi-limb
## division that allocates, and Euclid runs it ten to twenty times (250 ns on
## single-limb operands against 14 ns for the same gcd on `int64`). Euclid
## shrinks its operands fast, so the overload runs the big loop only while one
## still exceeds a limb and finishes in machine words.
import contracts
import ../arithmetic

func gcd*[T](a, b: T): T {.contractual.} =
  ## Euclidean GCD of `a` and `b`, always non-negative. Raises `OverflowDefect`
  ## only when the gcd itself is `MinInt` (e.g. `gcd(MinInt, 0)`), a magnitude
  ## that does not fit `T`.
  body:
    var u = a
    var v = b
    let zero = default(T)
    while v != zero:
      when T is SomeSignedInt:
        # `MinInt mod -1` is UB in C and faults on the x86 divide, even though
        # the gcd is plainly 1 for either unit divisor. `BigInt` has no such
        # limit, so the guard is machine-integer only.
        if v == T(1) or v == T(-1): return T(1)
      let r = u mod v
      u = v
      v = r
    if u < zero:
      {.push overflowChecks: on.}
      u = -u
      {.pop.}
    return u


func gcd*(a, b: BigInt): BigInt {.contractual.} =
  ## GCD of two `BigInt`, always non-negative.
  ##
  ## Euclid on magnitudes, dropping to `uint64` as soon as both operands fit a
  ## limb -- which, for the small rationals that dominate `Rational[BigInt]`,
  ## is immediately. Same result as the generic loop, exercised against it in
  ## `test_rational`.
  body:
    var u = a.mag
    var v = b.mag
    while u.limbs.len > 1 or v.limbs.len > 1:
      if isZero(v): break
      let r = u mod v
      u = v
      v = r
    if isZero(v):
      return initBigInt(u, false)
    var uw = if u.limbs.len == 0: ZeroLimb else: u.limbs[0]
    var vw = if v.limbs.len == 0: ZeroLimb else: v.limbs[0]
    while vw != ZeroLimb:
      let r = uw mod vw
      uw = vw
      vw = r
    initBigInt(initBigUInt(uw), false)

func lcm*[T](a, b: T): T {.contractual.} =
  ## `|a * b| / gcd(a, b)`, dividing before multiplying to limit intermediate
  ## growth. Zero is returned when either operand is zero. The multiplication
  ## and the `MinInt` negation run under a forced `overflowChecks` push so an
  ## unrepresentable product surfaces as `OverflowDefect` even in release (a
  ## no-op for `BigInt`, whose `*`/`-` are user procs).
  body:
    let zero = default(T)
    if a == zero or b == zero:
      return zero
    let g = gcd(a, b)
    var res: T
    {.push overflowChecks: on.}
    res = (a div g) * b
    if res < zero:
      res = -res
    {.pop.}
    return res
