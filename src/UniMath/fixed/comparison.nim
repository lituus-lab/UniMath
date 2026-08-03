# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-point comparison. Two values with the same `FracBits` share one scale,
## so comparing them is exactly comparing their raw integers.
import ./fixed_point
import contracts

func cmp*[T; FracBits: static[int]](a, b: Fixed[T,
    FracBits]): int {.contractual.} =
  ## Trichotomy compare. Asserted over the integer result only — no contracted
  ## call (recursion doctrine).
  ensure:
    result >= -1 and result <= 1
  body:
    if a.data > b.data: return 1
    if a.data < b.data: return -1
    return 0

func `==`*[T; FracBits: static[int]](a, b: Fixed[T,
    FracBits]): bool {.inline.} =
  a.data == b.data

func `<`*[T; FracBits: static[int]](a, b: Fixed[T, FracBits]): bool {.inline.} =
  a.data < b.data

func `<=`*[T; FracBits: static[int]](a, b: Fixed[T,
    FracBits]): bool {.inline.} =
  a.data <= b.data

func `>`*[T; FracBits: static[int]](a, b: Fixed[T, FracBits]): bool {.inline.} =
  a.data > b.data

func `>=`*[T; FracBits: static[int]](a, b: Fixed[T,
    FracBits]): bool {.inline.} =
  a.data >= b.data
