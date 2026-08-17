# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Integer square root — the largest `r` with `r * r <= n`.
##
## Two implementations, picked by operand type. Generic `Integer` types use the
## division-free digit-by-digit loop; `BigInt`/`BigUInt` use Newton from a
## float64 seed, since the digit-by-digit loop allocates once per two bits and
## Newton reaches 256 bits from a 53-bit seed in three divisions.
##
## Newton for integer square roots, and the requirement that the seed be an
## OVERESTIMATE for the iteration to descend monotonically to the floor, are
## standard: Brent & Zimmermann, *Modern Computer Arithmetic*, section 1.5.1
## (Cambridge University Press, 2010; the authors' PDF is freely available).
## Written from the algorithm, not transcribed from any implementation.
import std/math
import contracts
import ../arithmetic

func isqrt*[T: Integer](n: T): T {.contractual.} =
  ## Largest `r` with `r * r <= n`. Bounded by `Integer` so the public API is
  ## a concept, not implicit duck-typing.
  ##
  ## Domain guard (body `raise`, survives `-d:release`): `isqrt` is undefined
  ## for negative `n`. No inline `ensure:` — `n == default(T)` resolves, for
  ## `BigInt`, to the contracted `cmp` (re-entrant from an ensure); the
  ## zero-structure identity (`isqrt(0) == 0`, `isqrt(n) > 0` for `n > 0`) is
  ## exercised by the test suite.
  body:
    let zero = default(T)
    if n < zero:
      raise newException(ValueError, "isqrt: argument must be non-negative")
    if n == zero:
      return zero

    let one = n div n

    # Highest power of 4 that is <= n. Shift by 2 (powers of 4); stop on
    # overflow so this is safe on FixedInt/BigInt without a known bit width.
    var bit = one
    while bit <= n:
      let nextBit = bit shl 2
      if nextBit < bit: break
      bit = nextBit
    if bit > n:
      bit = bit shr 2

    var res = zero
    var num = n
    while bit != zero:
      if num >= res + bit:
        num = num - (res + bit)
        res = (res shr 1) + bit
      else:
        res = res shr 1
      bit = bit shr 2

    return res

func isqrtSeed(n: BigUInt, bl: int): BigUInt =
  ## An OVERESTIMATE of `sqrt(n)`, accurate to about 31 bits.
  ##
  ## Newton's integer iteration descends monotonically to `floor(sqrt(n))` only
  ## when started at or above the true root; started below, it can oscillate
  ## between two neighbours and never settle. So the bound here is constructed
  ## rather than hoped for.
  ##
  ## Write `n = top * 2^e + rem` with `e` even and `rem < 2^e`. Then
  ## `sqrt(n) < sqrt(top + 1) * 2^(e/2)`, and rounding that square root up in
  ## float64 keeps the inequality: the `+ 1` covers both the float rounding and
  ## the truncation back to an integer.
  var e = bl - 62
  if e < 0: e = 0
  e = e - (e mod 2) # even, so the shift halves exactly
  let top = n.bitWindow(Natural(e)) # the leading <= 62 bits of n
  let s = uint64(sqrt(float64(top) + 1.0)) + 1'u64
  initBigUInt(s) shl Natural(e div 2)

func isqrt*(n: BigUInt): BigUInt {.contractual.} =
  ## Largest `r` with `r * r <= n`, by Newton's method.
  ##
  ## No `ensure:` on `r*r <= n < (r+1)^2`: a postcondition must not re-derive
  ## the result, and squaring the answer at this width is the body's own cost
  ## again. The identity is exercised exhaustively in `tests/test_roots.nim`
  ## against the digit-by-digit implementation, which is independent of this
  ## one.
  body:
    if isZero(n): return n
    let bl = bitLength(n)
    if bl <= 2: return initBigUInt(1'u64) # n is 1, 2 or 3

    var x = isqrtSeed(n, bl)
    # Descend. Each step roughly doubles the correct digits, and the guard is
    # `y >= x` rather than a fixed count: from an overestimate the sequence is
    # strictly decreasing until it reaches the floor, where it stalls.
    while true:
      let y = (x + (n div x)) shr 1
      if y >= x: break
      x = y
    x

func isqrt*(n: BigInt): BigInt {.contractual.} =
  ## Largest `r` with `r * r <= n`. Negative input is a domain error, raised
  ## from the body so it survives `-d:release`.
  body:
    if n.isNegative:
      raise newException(ValueError, "isqrt: argument must be non-negative")
    initBigInt(isqrt(n.mag), false)
