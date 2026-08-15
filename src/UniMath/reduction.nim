# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Argument range reduction for `BigFloat` transcendentals.
##
## The generic Taylor primitives (`sinTaylor`/`cosTaylor` in `trigonometry`,
## `expTaylor`/`lnGeneric` in `exponential`) are exact but converge usefully
## only for small arguments: `sin`/`cos` Taylor at `|x| ~ 1e10` obliterates 256
## bits of precision long before the series turns around (the leading terms are
## `~1e33`, the answer is `~1`); `exp` at `|x| ~ 700` hits `~1e304`. The `Field`
## concept the generics are bounded by carries no notion of `pi`, so range
## reduction lives here, at the `BigFloat` layer, where the constants are.
##
## This module holds the reduction infrastructure shared by the `float_math`
## transcendentals (commit 23): power-of-two scaling, the cached `pi`/`2*pi`,
## `floor`/`round` over `BigFloat`, and `reduceModTwoPi` (the trig stage-1
## reduction `r = x - round(x/2pi)·2pi` into `[-pi, pi]`). Precision-keyed pi,
## its octant multiples, and `ln(2)` are cached in `float_math`, next to their
## consumers.
##
## The cache-reading procs are `proc` (not `func`): reading a module-level `let`
## is flagged as global-state access by Nim's strict effect system, so the
## procs that consult `piCache` cannot carry `.noSideEffect`. The cache is
## immutable after module init — a purity annotation only, no observable
## mutation at call time.
##
## Contracts: `{.contractual.}` + `body:` only — no inline `ensure:`. These are
## approximate algorithms whose postconditions would re-evaluate a contracted
## primitive or a `BigFloat` comparison delegating to the contracted `cmp`
## (recursion doctrine). The identities are documented per-proc and verified
## externally by the `float_math` MPFR oracle.
import contracts
import ./float
import ./arithmetic
import ./constants

func scaleByPow2*(x: BigFloat, k: int): BigFloat {.contractual, inline.} =
  ## `x · 2^k` by exponent adjustment only — no mantissa change, no rounding.
  ## `k < 0` divides. Preserves normalization (the top bit stays set). This is
  ## the exp/log range-reduction primitive (scaling by `2^k` is exact).
  body:
    result = x
    result.exponent = x.exponent + int64(k)

# Cached 256-bit pi and 2*pi, computed once at module load (a 96-term Machin
# evaluation ~10^4 BigFloat ops) and reused — never per call.
let piCache: BigFloat = piBigFloat(256)
let twoPiCache: BigFloat = piCache + piCache

proc piConst*: BigFloat {.contractual, inline.} =
  ## The cached 256-bit pi. Reads the module-level immutable `piCache` (hence a
  ## `proc`, not a `func` — see the header note on Nim's effect system).
  body:
    piCache

func floorBigFloat*(x: BigFloat, precision: int = 256): BigFloat {.contractual.} =
  ## Largest integer `<= x`, as a normalized `BigFloat`.
  body:
    if x.isZero: return x
    if x.exponent >= 0:
      # `m · 2^e` with e >= 0 is already an integer.
      result = x
      result.normalize(precision)
      return
    # e < 0: the low `-e` bits of the mantissa are fractional.
    let fracBits = -int(x.exponent)
    let intPart = x.mantissa shr fracBits
    let fracMask = (initBigUInt(1'u64) shl fracBits) - initBigUInt(1'u64)
    let dropped = x.mantissa and fracMask
    result.sign = x.sign
    result.mantissa = intPart
    result.exponent = 0
    if x.sign and not isZero(dropped):
      # floor of a negative non-integer is one below the truncation.
      let one = initBigFloat(1.0, precision)
      result = result - one
    else:
      result.normalize(precision)

func roundBigFloat*(x: BigFloat, precision: int = 256): BigFloat {.contractual.} =
  ## Nearest integer to `x` (round half up), as a `BigFloat`. More than good
  ## enough for `n = round(x/2pi)`: an off-by-one in `n` only shifts the
  ## residue by `2*pi`, which the octant fold then absorbs.
  body:
    let half = initBigFloat(0.5, precision)
    floorBigFloat(x + half, precision)

proc reduceModTwoPi*(x: BigFloat): BigFloat {.contractual.} =
  ## `r = x - round(x/2pi)·2pi`, brought into `[-pi, pi]`. The caller (a
  ## transcendental) skips this when `|x| <= pi` (`round(x/2pi) = 0`, `r = x`),
  ## so the common small-argument case pays no division.
  body:
    let n = roundBigFloat(x / twoPiCache)
    x - n * twoPiCache
