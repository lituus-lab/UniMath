# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Limb-level arithmetic primitives: add-with-carry, sub-with-borrow, wide
## multiply, and multiply-accumulate. The patterns (`sum = a + b; carry = sum <
## a`) lower to ADC/SBB on amd64; no inline asm, so the code is portable.
import ./limbs

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

func mulWide*(a, b: Limb, hi: var Limb): Limb {.inline.} =
  ## `(hi, lo) = a * b` via schoolbook on 32-bit halves (no uint128 needed).
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
when (defined(gcc) or defined(clang)) and not defined(noInt128):
  const hasInt128 = true
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
else:
  const hasInt128 = false

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
