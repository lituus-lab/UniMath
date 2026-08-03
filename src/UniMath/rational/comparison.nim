# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Rational comparison. The positive-denominator invariant makes equality a
## direct field compare and inequality a cross-product `x.num * y.den` vs
## `y.num * x.den`. Bounded integers use the sign plus an exact 128-bit
## magnitude product (`absToU64`/`cmpMul128`, so the cross-products never wrap);
## `BigInt` cross-multiplies directly (exact). Trichotomy is the only
## `ensure:`; the full ordering is exercised by the rational tests.
import ../arithmetic
import ./rational_type
import contracts

func signOf*(v: SomeSignedInt): int {.inline.} =
  if v > 0: 1 elif v < 0: -1 else: 0

func signOf*(v: SomeUnsignedInt): int {.inline.} =
  if v == 0: 0 else: 1

# Cross-product compare `nx/dx` vs `ny/dy` (`dx`, `dy > 0` by the invariant).
func cmpCross*[T: SomeInteger](nx, dx, ny, dy: T): int {.contractual.} =
  ensure:
    result >= -1 and result <= 1
  body:
    let sx = signOf(nx)
    let sy = signOf(ny)
    if sx != sy:
      return if sx > sy: 1 else: -1
    if sx == 0:
      return 0
    # Same sign: compare |nx|*dy vs |ny|*dx as 128-bit products (absToU64 is
    # MinInt-safe). Positive -> larger magnitude is greater; negative -> lesser.
    let m = cmpMul128(absToU64(nx), uint64(dy), absToU64(ny), uint64(dx))
    return if sx > 0: m else: -m

func cmpCross*(nx, dx, ny, dy: BigInt): int {.contractual.} =
  ensure:
    result >= -1 and result <= 1
  body:
    let crossX = nx * dy
    let crossY = ny * dx
    if crossX > crossY: return 1
    elif crossX < crossY: return -1
    return 0

func cmp*[T](x, y: Rational[T]): int {.contractual.} =
  ## Trichotomy: `1` if `x > y`, `0` if equal, `-1` if `x < y`. Equality is a
  ## fast field compare (the fraction is irreducible); otherwise dispatches to
  ## `cmpCross` on the storage type `T`.
  ensure:
    result >= -1 and result <= 1
  body:
    if x.num == y.num and x.den == y.den:
      return 0
    return cmpCross(x.num, x.den, y.num, y.den)

func `==`*[T](x, y: Rational[T]): bool {.inline.} =
  x.num == y.num and x.den == y.den

func `<`*[T](x, y: Rational[T]): bool {.inline.} =
  cmp(x, y) < 0

func `<=`*[T](x, y: Rational[T]): bool {.inline.} =
  cmp(x, y) <= 0

func `>`*[T](x, y: Rational[T]): bool {.inline.} =
  cmp(x, y) > 0

func `>=`*[T](x, y: Rational[T]): bool {.inline.} =
  cmp(x, y) >= 0

func `<`*[T](x: Rational[T], y: T): bool {.inline.} =
  x < toRational(y)

func `==`*[T](x: Rational[T], y: T): bool {.inline.} =
  x == toRational(y)
