# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Limb-array operations: correct scalar plus an opt-in SIMD backend for the
## genuinely vectorizable bitwise ops (and/or/xor — no inter-limb dependency).
## Addition/subtraction stay scalar (the carry chain is sequential). The SIMD
## backend is opt-in: `nim c -d:simd` (NEON on arm64, SSE2 on amd64); the core
## stays dependency-free otherwise.
import ./limbs
import ./primitives

when defined(simd):
  when defined(arm64) or defined(aarch64):
    import nimsimd/neon
    const simdBackend = "NEON (nimsimd)"
  elif defined(amd64) or defined(x86_64):
    import nimsimd/sse2
    const simdBackend = "SSE2 (nimsimd)"
  else:
    const simdBackend = "scalar (no nimsimd backend for this architecture)"
else:
  const simdBackend = "scalar"

func addCArray*(a, b: openArray[Limb], res: var seq[Limb], carryOut: var Limb) =
  ## Multi-limb addition `res = a + b` with outgoing carry. Unequal lengths
  ## accepted (the shorter operand is zero-extended). Scalar — the carry chain
  ## does not vectorize.
  let common = min(a.len, b.len)
  res.setLen(max(a.len, b.len))
  var carry = ZeroLimb
  for i in 0 ..< common:
    res[i] = addC(carry, a[i], b[i], carry)
  for i in common ..< a.len:
    res[i] = addC(carry, a[i], ZeroLimb, carry)
  for i in common ..< b.len:
    res[i] = addC(carry, ZeroLimb, b[i], carry)
  carryOut = carry

func subBArray*(a, b: openArray[Limb], res: var seq[Limb],
    borrowOut: var Limb) =
  ## Multi-limb subtraction `res = a - b` with outgoing borrow. Requires
  ## `b.len <= a.len` (asserted).
  doAssert b.len <= a.len, "subBArray: b longer than a"
  res.setLen(a.len)
  var borrow = ZeroLimb
  for i in 0 ..< b.len:
    res[i] = subB(borrow, a[i], b[i], borrow)
  for i in b.len ..< a.len:
    res[i] = subB(borrow, a[i], ZeroLimb, borrow)
  borrowOut = borrow

func mulArray*(a, b: openArray[Limb], res: var seq[Limb]) =
  ## Full schoolbook product `res = a * b` (`res.len = a.len + b.len`).
  res.setLen(a.len + b.len)
  for i in 0 ..< res.len:
    res[i] = ZeroLimb
  for i in 0 ..< a.len:
    var carry = ZeroLimb
    for j in 0 ..< b.len:
      res[i + j] = mulAdd(a[i], b[j], res[i + j], carry)
    res[i + b.len] = carry

when defined(simd) and (defined(arm64) or defined(aarch64)):
  func andArray*(a, b: openArray[Limb], res: var seq[Limb]) =
    ## Limb-wise bitwise AND — NEON, 2 limbs per 128-bit register.
    doAssert a.len == b.len
    res.setLen(a.len)
    var i = 0
    while i + 2 <= a.len:
      let va = vld1q_u64(cast[ptr uint64](unsafeAddr a[i]))
      let vb = vld1q_u64(cast[ptr uint64](unsafeAddr b[i]))
      vst1q_u64(cast[ptr uint64](addr res[i]), vandq_u64(va, vb))
      i += 2
    while i < a.len:
      res[i] = a[i] and b[i]
      inc i

  func orArray*(a, b: openArray[Limb], res: var seq[Limb]) =
    ## Limb-wise bitwise OR — NEON.
    doAssert a.len == b.len
    res.setLen(a.len)
    var i = 0
    while i + 2 <= a.len:
      let va = vld1q_u64(cast[ptr uint64](unsafeAddr a[i]))
      let vb = vld1q_u64(cast[ptr uint64](unsafeAddr b[i]))
      vst1q_u64(cast[ptr uint64](addr res[i]), vorrq_u64(va, vb))
      i += 2
    while i < a.len:
      res[i] = a[i] or b[i]
      inc i

  func xorArray*(a, b: openArray[Limb], res: var seq[Limb]) =
    ## Limb-wise bitwise XOR — NEON.
    doAssert a.len == b.len
    res.setLen(a.len)
    var i = 0
    while i + 2 <= a.len:
      let va = vld1q_u64(cast[ptr uint64](unsafeAddr a[i]))
      let vb = vld1q_u64(cast[ptr uint64](unsafeAddr b[i]))
      vst1q_u64(cast[ptr uint64](addr res[i]), veorq_u64(va, vb))
      i += 2
    while i < a.len:
      res[i] = a[i] xor b[i]
      inc i

elif defined(simd) and (defined(amd64) or defined(x86_64)):
  func andArray*(a, b: openArray[Limb], res: var seq[Limb]) =
    ## Limb-wise bitwise AND — SSE2, 2 limbs per 128-bit register.
    doAssert a.len == b.len
    res.setLen(a.len)
    var i = 0
    while i + 2 <= a.len:
      let va = mm_loadu_si128(cast[ptr M128i](unsafeAddr a[i]))
      let vb = mm_loadu_si128(cast[ptr M128i](unsafeAddr b[i]))
      mm_storeu_si128(cast[ptr M128i](addr res[i]), mm_and_si128(va, vb))
      i += 2
    while i < a.len:
      res[i] = a[i] and b[i]
      inc i

  func orArray*(a, b: openArray[Limb], res: var seq[Limb]) =
    ## Limb-wise bitwise OR — SSE2.
    doAssert a.len == b.len
    res.setLen(a.len)
    var i = 0
    while i + 2 <= a.len:
      let va = mm_loadu_si128(cast[ptr M128i](unsafeAddr a[i]))
      let vb = mm_loadu_si128(cast[ptr M128i](unsafeAddr b[i]))
      mm_storeu_si128(cast[ptr M128i](addr res[i]), mm_or_si128(va, vb))
      i += 2
    while i < a.len:
      res[i] = a[i] or b[i]
      inc i

  func xorArray*(a, b: openArray[Limb], res: var seq[Limb]) =
    ## Limb-wise bitwise XOR — SSE2.
    doAssert a.len == b.len
    res.setLen(a.len)
    var i = 0
    while i + 2 <= a.len:
      let va = mm_loadu_si128(cast[ptr M128i](unsafeAddr a[i]))
      let vb = mm_loadu_si128(cast[ptr M128i](unsafeAddr b[i]))
      mm_storeu_si128(cast[ptr M128i](addr res[i]), mm_xor_si128(va, vb))
      i += 2
    while i < a.len:
      res[i] = a[i] xor b[i]
      inc i

else:
  func andArray*(a, b: openArray[Limb], res: var seq[Limb]) =
    ## Limb-wise bitwise AND (scalar fallback).
    doAssert a.len == b.len
    res.setLen(a.len)
    for i in 0 ..< a.len: res[i] = a[i] and b[i]

  func orArray*(a, b: openArray[Limb], res: var seq[Limb]) =
    ## Limb-wise bitwise OR (scalar fallback).
    doAssert a.len == b.len
    res.setLen(a.len)
    for i in 0 ..< a.len: res[i] = a[i] or b[i]

  func xorArray*(a, b: openArray[Limb], res: var seq[Limb]) =
    ## Limb-wise bitwise XOR (scalar fallback).
    doAssert a.len == b.len
    res.setLen(a.len)
    for i in 0 ..< a.len: res[i] = a[i] xor b[i]

func getSimdFeatures*(): string =
  ## Describes the effective vector configuration.
  simdBackend & " (" & $LimbBits & "-bit limbs)"

func simdBitwiseSupported*(): bool =
  ## True when the bitwise operations go through real intrinsics (nimsimd).
  when defined(simd) and
       (defined(arm64) or defined(aarch64) or defined(amd64) or defined(x86_64)):
    true
  else:
    false
