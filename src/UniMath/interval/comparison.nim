# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Interval comparison. `==` is the set-equality of two degenerate, identical
## intervals (the only case where equality is decidable); `<` and `<=` are the
## strict / non-strict "certainly less-than" relations (upper of one below the
## lower of the other). The latter two are not contracted: their truth is a
## direct field comparison, so an ensure would just re-state the body.
import contracts
import ./interval_type

func `==`*[T](a, b: Interval[T]): bool {.contractual, inline.} =
  ## True only when both intervals are degenerate points and equal — the sole
  ## case where interval equality is decidable without extra assumptions.
  ensure:
    result == ((a.lower == a.upper) and (b.lower == b.upper) and
               (a.lower == b.lower))
  body:
    (a.lower == a.upper) and (b.lower == b.upper) and (a.lower == b.lower)

func `<`*[T](a, b: Interval[T]): bool {.inline.} =
  ## `a` certainly below `b`: `a.upper < b.lower`.
  a.upper < b.lower

func `<=`*[T](a, b: Interval[T]): bool {.inline.} =
  ## `a` certainly at-or-below `b`: `a.upper <= b.lower`.
  a.upper <= b.lower
