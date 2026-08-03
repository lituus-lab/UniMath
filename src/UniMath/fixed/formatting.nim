# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-point conversion and formatting. `toFloat`/`toFloat64` scale the raw
## integer down by `2^FracBits`; `$` renders via the float form (may lose
## precision when `T` holds more than the 53-bit float mantissa).
import ./fixed_point
import ../arithmetic

func toFloat*[T; FracBits: static[int]](a: Fixed[T, FracBits]): float =
  ## Convert to a standard float. `pow2f64(FracBits)` is the exact `2^FracBits`
  ## for every `FracBits`; the old `uint64(1) shl FracBits` wrapped to 0.0 once
  ## `FracBits >= 64` (e.g. `Fixed[BigInt, 100]`), dividing by 0.0.
  let scale = float(pow2f64(FracBits))
  float(a.data) / scale

func toFloat64*[T; FracBits: static[int]](a: Fixed[T,
    FracBits]): float64 {.inline.} =
  ## Alias for `toFloat`, matching the UniFloat/UniRational API.
  a.toFloat()

func `$`*[T; FracBits: static[int]](a: Fixed[T, FracBits]): string =
  ## String form via the float conversion.
  $toFloat(a)
