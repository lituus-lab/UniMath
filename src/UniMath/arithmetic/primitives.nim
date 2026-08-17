# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Limb-level arithmetic primitives: add-with-carry, sub-with-borrow, wide
## multiply, and multiply-accumulate. The patterns (`sum = a + b; carry = sum <
## a`) lower to ADC/SBB on amd64; no inline asm, so the code is portable.
##
## `mulWide` has a native fast path where the toolchain offers a 64x64->128
## multiply, and the portable 32x32 decomposition everywhere else. Both are
## exported and both are covered by `tests/test_primitives.nim`, which checks
## each against a third, independent 16-bit reference — a fast path that agreed
## only with the implementation it replaced would prove nothing.
import ./limbs

const
  hasInt128* = (defined(gcc) or defined(clang)) and defined(cpu64) and
               not defined(noInt128)
    ## `unsigned __int128`, a GCC/Clang extension. The compilers document it as
    ## "supported for targets which have an integer mode wide enough to hold
    ## 128 bits" and expose `__SIZEOF_INT128__` to detect it; a Nim `when`
    ## cannot read a C macro, so `cpu64` stands in for it and the emitted C
    ## carries a `#error` that names `-d:noInt128` if the two ever disagree.
    ##
    ## `cpu64` is load-bearing: 32-bit GCC has no 128-bit integer mode, and
    ## before this guard the `udiv128` emit below would fail to compile there.
  hasUmul128* = defined(vcc) and defined(amd64) and not defined(noInt128)
    ## MSVC's `_umul128` intrinsic: x64 only, declared in <intrin.h>.
  hasNativeWide* = hasInt128 or hasUmul128

# ONLY `mulWide` gets a native path, not `mulAdd`. Measured on amd64/clang,
# composing `mulAdd` from a native `mulWide` plus the existing `addC` chain
# lands within 2-6% of a fully fused `__int128` multiply-add (256-bit: 26.2 vs
# 24.6 ns; 4096-bit: 3345 vs 3275 ns). That is not worth a second intrinsic per
# toolchain — and on MSVC it would mean `_addcarry_u64` as well, on a platform
# this cannot be compiled for here. `mulAdd` keeps its tested body and inherits
# the speedup through `mulWide`.
when hasNativeWide:
  # A header, not an `{.emit.}`: `mulWide` is `{.inline.}`, so its callers
  # inline it into their own translation units, where a definition emitted only
  # into `primitives.nim.c` is invisible and the link fails. The header's own
  # `#if` also lets the C compiler make the final choice from its feature
  # macros, so a target Nim guessed wrong about gets a directed #error.
  import std/os
  proc mulWideC(a, b: Limb, hi: var Limb): Limb {.importc: "unimath_mulwide",
      header: currentSourcePath().parentDir / "limb_intrinsics.h".}

func addC*(carryIn: Limb, a, b: Limb, carryOut: var Limb): Limb {.inline.} =
  ## `r = a + b + carryIn`; `carryOut` is 0 or 1.
  let partial = a + b
  let c1 = if partial < a: OneLimb else: ZeroLimb
  let total = partial + carryIn
  let c2 = if total < partial: OneLimb else: ZeroLimb
  carryOut = c1 or c2
  total

func subB*(borrowIn: Limb, a, b: Limb, borrowOut: var Limb): Limb {.inline.} =
  ## `r = a - b - borrowIn`; `borrowOut` is 0 or 1.
  let borrow1 = if a < b: OneLimb else: ZeroLimb
  let partial = a - b
  let borrow2 = if partial < borrowIn: OneLimb else: ZeroLimb
  borrowOut = borrow1 or borrow2
  partial - borrowIn

func mulWidePortable*(a, b: Limb, hi: var Limb): Limb {.inline.} =
  ## `(hi, lo) = a * b` via schoolbook on 32-bit halves, using nothing wider
  ## than a Limb. The fallback for toolchains without a 128-bit multiply, and
  ## the differential reference for the native path on those that have one.
  const HalfBits = LimbBits div 2
  const HalfMask = (OneLimb shl HalfBits) - 1
  let aLo = a and HalfMask
  let aHi = a shr HalfBits
  let bLo = b and HalfMask
  let bHi = b shr HalfBits
  let p00 = aLo * bLo
  let p01 = aLo * bHi
  let p10 = aHi * bLo
  let p11 = aHi * bHi
  let mid = p01 + p10
  let midCarry = if mid < p01: (OneLimb shl HalfBits) else: ZeroLimb
  let midLo = (mid and HalfMask) shl HalfBits
  let midHi = mid shr HalfBits
  let resLo = p00 + midLo
  let loCarry = if resLo < p00: OneLimb else: ZeroLimb
  hi = p11 + midHi + midCarry + loCarry
  resLo

func mulWide*(a, b: Limb, hi: var Limb): Limb {.inline.} =
  ## `(hi, lo) = a * b`. One `mulq`/`umulh` where the toolchain has a 128-bit
  ## multiply, the 32x32 decomposition otherwise. Measured on amd64/clang, the
  ## native path is 1.7x-2.7x faster inside a schoolbook multiply (256-bit:
  ## 41.3 -> 24.2 ns/op; 4096-bit: 8623 -> 3247 ns/op), which propagates to
  ## every big-integer multiply, the fixed-width multiply and the division
  ## quotient estimate.
  when hasNativeWide:
    mulWideC(a, b, hi)
  else:
    mulWidePortable(a, b, hi)

func mulAdd*(a, b, c: Limb, carry: var Limb): Limb {.inline.} =
  ## `(a*b) + c + carry` -> low Limb returned, high half in `carry`. The result
  ## fits 128 bits, so the carry (hi + two add-carries) fits a Limb.
  var hi: Limb
  let prodLo = mulWide(a, b, hi)
  var cCarry: Limb
  let t1 = addC(ZeroLimb, prodLo, c, cCarry)
  var finalCarry: Limb
  let res = addC(ZeroLimb, t1, carry, finalCarry)
  carry = hi + cCarry + finalCarry
  res

# Limb-level 128/64 division and leading-zero count. The division is long
# division (Knuth, TAOCP vol. 2 §4.3.1); the 128/64 step uses the compiler's
# `__int128` extension and the leading-zero count uses `__builtin_clzll`
# (GCC/Clang language extensions — not assembly copied from any library) where
# available, with portable bit-serial fallbacks elsewhere. No third-party code.
when hasInt128:
  {.emit: """
void unimath_udiv128(unsigned long long hi, unsigned long long lo,
                     unsigned long long d, unsigned long long *q,
                     unsigned long long *rem) {
  unsigned __int128 n = ((unsigned __int128)hi << 64) | (unsigned __int128)lo;
  *q = (unsigned long long)(n / (unsigned __int128)d);
  *rem = (unsigned long long)(n % (unsigned __int128)d);
}
int unimath_clz64(unsigned long long x) {
  return x == 0 ? 64 : __builtin_clzll(x);
}
""".}
  proc udiv128C(hi, lo, d: Limb; q, rem: ptr Limb) {.importc: "unimath_udiv128",
      cdecl.}
  proc clz64C(x: Limb): int32 {.importc: "unimath_clz64", cdecl.}

func clzLimb*(x: Limb): int {.inline.} =
  ## Leading zero bits of `x` (`LimbBits` when `x == 0`). Hardware
  ## `__builtin_clzll` where available (one instruction); a portable bit-serial
  ## fallback elsewhere. Hot path: `bitLength` calls this on the top limb of
  ## every `normalize`, so a normalized mantissa (top bit set) is one cycle, not
  ## a 64-iteration loop.
  when hasInt128:
    int(clz64C(x))
  else:
    result = LimbBits
    var t = x
    while t != 0:
      t = t shr 1
      dec result

func udiv128*(hi, lo, d: Limb): tuple[quot, rem: Limb] {.inline.} =
  ## `(hi:lo) / d` -> quotient and remainder. Requires `hi < d` (so the quotient
  ## fits a Limb) and `d != 0`. One limb-level long-division step. The guard is
  ## a body raise, matching `divmod128by64`: without it the `hasInt128` path
  ## faults on the hardware divide while the portable loop returns garbage, so
  ## an invalid caller would fail differently per backend.
  if d == ZeroLimb:
    raise newException(DivByZeroDefect, "udiv128: divisor is zero")
  if hi >= d:
    raise newException(ValueError,
      "udiv128: high limb must be < divisor (quotient must fit a Limb)")
  when hasInt128:
    var q, r: Limb
    udiv128C(hi, lo, d, addr q, addr r)
    (q, r)
  else:
    # Portable 128/64 bit-serial: `rem` (the running remainder, `rem < d`) is
    # shifted left one bit at a time, fed the next dividend bit, and reduced.
    # The top bit is captured before the shift so `rem shl 1` cannot overflow.
    var rem = hi
    var quot: Limb = ZeroLimb
    for i in countDown(LimbBits - 1, 0):
      let carry = rem shr (LimbBits - 1)
      rem = (rem shl 1) or ((lo shr i) and OneLimb)
      quot = quot shl 1
      if carry != 0 or rem >= d:
        rem = rem - d
        quot = quot or OneLimb
    (quot, rem)
