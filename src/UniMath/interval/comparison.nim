# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Interval comparison. `==` is set equality -- identical endpoints, degenerate
## or not -- and `certainlyEqual` is the decidable "both are the same point"
## relation; `<` and `<=` are the strict / non-strict "certainly less-than"
## relations (upper of one below the lower of the other). All but
## `certainlyEqual` are uncontracted: their truth is a direct field comparison,
## so an ensure would just re-state the body.
import contracts
import ./interval_type

func `==`*[T](a, b: Interval[T]): bool {.inline.} =
  ## Set equality: same endpoints. This is IEEE 1788's `equal`, and it keeps
  ## `==` reflexive, which Nim assumes everywhere a value is compared, stored
  ## or deduplicated — `a == a` was false for any non-degenerate `a` when this
  ## spelled the certainly-equal relation. That relation is `certainlyEqual`.
  a.lower == b.lower and a.upper == b.upper

func certainlyEqual*[T](a, b: Interval[T]): bool {.contractual, inline.} =
  ## True only when both intervals are degenerate points and equal — the sole
  ## case where the represented scalars are provably equal. Companion to the
  ## certainly-relations `<` and `<=` below.
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
