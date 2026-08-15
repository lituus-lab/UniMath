# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## String formatting. `$` is hexadecimal (base 16 maps directly to limbs, and is
## what the bitwise tests pin). `toDecimal` extracts base-10 chunks with one
## descending limb pass per chunk.
import strutils
import ./limbs
import ./primitives
import ./fixed_int
import ./big_int

func toHex*[Bits: static int](x: FixedUInt[Bits] | FixedInt[Bits]): string =
  ## Hex representation, big-endian (most-significant limb first).
  result = "0x"
  var started = false
  for i in countDown(x.limbs.high, 0):
    let limbVal = x.limbs[i]
    if not started:
      if limbVal == ZeroLimb and i > 0:
        continue
      var s = toHex(limbVal, LimbBytes * 2)
      s.removePrefix('0')
      if s.len == 0: s = "0"
      result.add(s)
      started = true
    else:
      result.add(toHex(limbVal, LimbBytes * 2))

func `$`*[Bits: static int](x: FixedUInt[Bits] | FixedInt[Bits]): string =
  toHex(x)

func toHex*(x: BigUInt): string =
  ## Hex representation of a `BigUInt`.
  if isZero(x): return "0x0"
  result = "0x"
  var firstLimb = toHex(x.limbs[x.limbs.high], LimbBytes * 2)
  firstLimb.removePrefix('0')
  result.add(firstLimb)
  for i in countDown(x.limbs.high - 1, 0):
    result.add(toHex(x.limbs[i], LimbBytes * 2))

func `$`*(x: BigUInt): string =
  toHex(x)

func toHex*(x: BigInt): string =
  ## Hex representation of a `BigInt` (leading `-` if negative).
  if x.isNegative: "-" & toHex(x.mag) else: toHex(x.mag)

func `$`*(x: BigInt): string =
  toHex(x)

func toDecimal*(x: BigUInt): string =
  ## Decimal representation of `x` (no prefix). Each pass divides the working
  ## magnitude by `10^19`, the largest decimal power that fits in one limb.
  ## `"0"` for the zero value.
  if isZero(x): return "0"
  const DecimalBase = Limb(10_000_000_000_000_000_000'u64)
  const DecimalDigits = 19
  var work = x.limbs
  var chunks: seq[Limb] = @[]
  while work.len > 0:
    var remainder = ZeroLimb
    for i in countDown(work.high, 0):
      let (quotient, rem) = udiv128(remainder, work[i], DecimalBase)
      work[i] = quotient
      remainder = rem
    while work.len > 0 and work[^1] == ZeroLimb:
      work.setLen(work.len - 1)
    chunks.add(remainder)

  result = $chunks[^1]
  for i in countDown(chunks.high - 1, 0):
    result.add(align($chunks[i], DecimalDigits, '0'))

func toDecimal*(x: BigInt): string =
  ## Signed decimal representation of `x` (no prefix; leading `-` if negative).
  if x.isNegative: "-" & toDecimal(x.mag) else: toDecimal(x.mag)

