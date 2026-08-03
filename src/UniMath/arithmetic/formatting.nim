# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## String formatting. `$` is hexadecimal (base 16 maps directly to limbs, and is
## what the bitwise tests pin). `toDecimal` produces a base-10 string by repeated
## `divMod` by 10 — needed for decimal-based oracles and human-facing output.
import strutils
import ./limbs
import ./fixed_int
import ./big_int
import ./division_big

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
  ## Decimal representation of `x` (no prefix). `O(digits * limbs)` — each digit
  ## costs one `divMod` by 10. `"0"` for the zero value.
  if isZero(x): return "0"
  var v = x
  var digits: seq[char] = @[]
  let ten = initBigUInt(10'u64)
  while not isZero(v):
    let (q, r) = divMod(v, ten)
    digits.add char(uint8('0') + uint8(toUInt64(r)))
    v = q
  result = newString(digits.len)
  for i in 0 ..< digits.len:
    result[i] = digits[digits.high - i]

func toDecimal*(x: BigInt): string =
  ## Signed decimal representation of `x` (no prefix; leading `-` if negative).
  if x.isNegative: "-" & toDecimal(x.mag) else: toDecimal(x.mag)



