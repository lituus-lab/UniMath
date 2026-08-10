# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Complex sub-umbrella: the generic `Complex[T]` type over any `Field`
## component, its arithmetic, equality and formatting. A near-leaf — it imports
## only `arithmetic` (for `fromInt`/`Field`) and `contracts`. The
## transcendentals live in `complex_math`, which sits above the real
## transcendental layers because `sqrt`/`ln`/`arctan2` on the component are
## what `abs`, `arg` and the complex `sqrt`/`ln` are built from.
##
## `Complex` shadows `std/complex`'s type of the same name, which is restricted
## to `SomeFloat`; importing both in one module is ambiguous. Qualify, or drop
## the `std/complex` import — `UniMath` covers `Complex[float64]` too.
import ./complex/complex_type
import ./complex/arithmetic
import ./complex/comparison
import ./complex/formatting
export complex_type, arithmetic, comparison, formatting
