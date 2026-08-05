# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Integer square root — the largest `r` with `r * r <= n`, via the
## digit-by-digit (binary) algorithm. No division, so it is safe on every
## `Integer`-concept type (built-in integers and `BigInt`).
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
