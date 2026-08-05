# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Arbitrary-precision unsigned division. A single-limb divisor takes the
## limb-level long-division fast path (one 128/64 step per dividend limb, MSB
## to LSB — Knuth, TAOCP vol. 2 §4.3.1); a multi-limb divisor takes the general
## Knuth Algorithm D (normalize, estimate each quotient limb with one 128/64
## step, correct, multiply-subtract, denormalize). Division by zero raises
## `DivByZeroDefect` (body raise). The reconstruction `q*b + r == a` is
## verified externally (an inline `ensure:` would call the contracted `*`/`+`).
import ./limbs
import ./primitives
import ./big_int
import ./comparison_big
import contracts

func divModLimb*(a: BigUInt, d: Limb): tuple[q: BigUInt,
    r: Limb] {.contractual.} =
  ## `a / d` for a single-limb divisor `d != 0`. Limb-level long division
  ## (Knuth §4.3.1): one `udiv128` step per dividend limb, most-significant
  ## first. `r` is the final remainder (`0 <= r < d`).
  body:
    # Before the zero-dividend shortcut: otherwise `divModLimb(0, 0)` returns
    # (0, 0) instead of rejecting, since it never reaches `udiv128`'s guard.
    # Body raise, like every other division-by-zero guard here.
    if d == ZeroLimb:
      raise newException(DivByZeroDefect, "divModLimb: divisor is zero")
    result.q = initBigUInt(0)
    if isZero(a):
      result.r = ZeroLimb
      return
    result.q.limbs = newSeq[Limb](a.limbs.len)
    var rem: Limb = ZeroLimb
    for i in countDown(a.limbs.high, 0):
      let (ql, rl) = udiv128(rem, a.limbs[i], d)
      result.q.limbs[i] = ql
      rem = rl
    result.q.trim()
    result.r = rem

func divModKnuth*(a, b: BigUInt): tuple[q, r: BigUInt] {.contractual.} =
  ## Multi-limb `a / b` via Knuth Algorithm D (TAOCP vol. 2 §4.3.1). The divisor
  ## is normalized (left-shifted so its top limb has the high bit set), each
  ## quotient limb is estimated with one 128/64 `udiv128` step and corrected
  ## against the next divisor limb, then a limb-level multiply-subtract writes
  ## the remainder window; a window that goes negative restores by adding the
  ## divisor back. The remainder is denormalized at the end. Public-domain
  ## algorithm; no third-party code.
  require:
    # `divMod` routes single-limb divisors to `divModLimb` and shorter dividends
    # to the early return, so the exported entry states both: `vNorm[n - 2]`
    # indexes -1 for `n == 1`, and a negative `m` gives `newSeq` a negative len.
    b.limbs.len >= 2
    a.limbs.len >= b.limbs.len
  body:
    let n = b.limbs.len
    let u = a.limbs
    let m = u.len - n # quotient has m + 1 limbs
                      # D1. Normalize: s = leading zeros of the top divisor limb.
    let s = clzLimb(b.limbs[n - 1])
    var vNorm = newSeq[Limb](n)
    var uNorm = newSeq[Limb](u.len + 1)
    if s == 0:
      for i in 0 ..< n:
        vNorm[i] = b.limbs[i]
      for i in 0 ..< u.len:
        uNorm[i] = u[i]
      uNorm[u.len] = ZeroLimb
    else:
      vNorm[0] = b.limbs[0] shl s
      for i in 1 ..< n:
        vNorm[i] = (b.limbs[i] shl s) or (b.limbs[i - 1] shr (LimbBits - s))
      uNorm[0] = u[0] shl s
      for i in 1 ..< u.len:
        uNorm[i] = (u[i] shl s) or (u[i - 1] shr (LimbBits - s))
      uNorm[u.len] = u[u.len - 1] shr (LimbBits - s)
    var qLimbs = newSeq[Limb](m + 1)
    # D2-D4. One quotient limb per pass, most-significant first.
    for j in countDown(m, 0):
      # D3. qhat estimate from the top two window limbs and the top divisor
      # limb. `uNorm[j+n] < vNorm[n-1]` is the Knuth invariant, so the quotient
      # fits a Limb; the `==` case saturates to `MaxLimb`.
      var qhat: Limb
      var rhat: Limb
      var rhatOvf = false # rhat >= b (cannot be stored in a Limb)
      if uNorm[j + n] == vNorm[n - 1]:
        qhat = MaxLimb
        let r2 = uNorm[j + n - 1] + vNorm[n - 1]
        rhatOvf = r2 < uNorm[j + n - 1]
        rhat = r2
      else:
        let (qh, rh) = udiv128(uNorm[j + n], uNorm[j + n - 1], vNorm[n - 1])
        qhat = qh
        rhat = rh
      # D3. Correct qhat while `qhat*vNorm[n-2] > rhat*b + uNorm[j+n-2]`. The
      # test compares two 128-bit values via the high/low halves; it runs at
      # most twice before `rhat` overflows and the estimate is settled.
      while not rhatOvf:
        var hi1: Limb
        let lo1 = mulWide(qhat, vNorm[n - 2], hi1)
        if hi1 > rhat or (hi1 == rhat and lo1 > uNorm[j + n - 2]):
          qhat -= 1
          let r2 = rhat + vNorm[n - 1]
          if r2 < rhat:
            rhatOvf = true
          else:
            rhat = r2
        else:
          break
      # D4. Multiply and subtract: `uNorm[j..j+n] -= qhat * vNorm`. The running
      # mul carry stays within a Limb (a Limb-pair product's high half is at
      # most `b-2`, plus a 1-bit add carry). A final borrow means qhat was one
      # too large: decrement and add the divisor back, the carry canceling the
      # borrow.
      var carry: Limb = 0
      var borrow: Limb = 0
      for i in 0 ..< n:
        var hi: Limb
        let lo = mulWide(qhat, vNorm[i], hi)
        var c1: Limb
        let loC = addC(ZeroLimb, lo, carry, c1)
        carry = hi + c1
        var bOut: Limb
        uNorm[j + i] = subB(borrow, uNorm[j + i], loC, bOut)
        borrow = bOut
      var bOut: Limb
      uNorm[j + n] = subB(borrow, uNorm[j + n], carry, bOut)
      if bOut != 0:
        qhat -= 1
        var c: Limb = 0
        for i in 0 ..< n:
          uNorm[j + i] = addC(c, uNorm[j + i], vNorm[i], c)
        uNorm[j + n] = uNorm[j + n] + c
      qLimbs[j] = qhat
    # D5. Denormalize the remainder (`uNorm[0..n-1] >> s`).
    var rLimbs = newSeq[Limb](n)
    if s == 0:
      for i in 0 ..< n:
        rLimbs[i] = uNorm[i]
    else:
      for i in 0 ..< n:
        let lo = uNorm[i] shr s
        let hi = if i + 1 < n: uNorm[i + 1] shl (LimbBits - s) else: ZeroLimb
        rLimbs[i] = lo or hi
    result.q = initBigUInt(qLimbs)
    result.r = initBigUInt(rLimbs)

func divMod*(a, b: BigUInt): tuple[q, r: BigUInt] {.contractual.} =
  ## Euclidean `a / b`: `q = floor(a/b)`, `0 <= r < b`.
  body:
    if isZero(b):
      raise newException(DivByZeroDefect, "Division by zero in BigUInt.")
    if a < b:
      return (q: initBigUInt(0), r: a)
    if b.limbs.len == 1:
      let (q, r) = divModLimb(a, b.limbs[0])
      return (q, initBigUInt(r))
    return divModKnuth(a, b)

func `div`*(a, b: BigUInt): BigUInt {.contractual, inline.} =
  body:
    let (q, _) = divMod(a, b)
    return q

func `mod`*(a, b: BigUInt): BigUInt {.contractual, inline.} =
  body:
    let (_, r) = divMod(a, b)
    return r
