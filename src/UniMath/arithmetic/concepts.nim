# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Algebraic concepts and uniform construction. `fromInt(T, v)` (typedesc
## overload) lets generic series build zero/one in any field type without an
## injected constructor; `zero(T)`/`one(T)` derive from it. Arity disambiguates
## these from the 1-arg `fromInt(val: int): BigInt` in `big_int`. BigFloat/Fixed/
## Rational add their own overloads in their packages (which import this).
import ./big_int

func fromInt*(T: typedesc[SomeInteger], v: int): T {.inline.} =
  T(v)

func fromInt*(T: typedesc[SomeFloat], v: int): T {.inline.} =
  T(v)

func fromInt*(T: typedesc[BigInt], v: int): BigInt {.inline.} =
  fromInt(v)

func fromFloat*(T: typedesc[SomeFloat], v: float64): T {.inline.} =
  T(v)

func fromFloat*(T: typedesc[BigInt], v: float64): BigInt {.inline.} =
  fromFloat(v)

func fromFloat*(T: typedesc[SomeInteger], v: float64): T {.inline.} =
  T(v)

func toFloat64*(v: SomeInteger): float64 {.inline.} =
  float64(v)

template zero*(F: typedesc): untyped =
  fromInt(F, 0)

template one*(F: typedesc): untyped =
  fromInt(F, 1)

type
  Field* = concept x, y
    x + y is typeof(x)
    x - y is typeof(x)
    x * y is typeof(x)
    x / y is typeof(x)
    -x is typeof(x)
    fromInt(typeof(x), 1) is typeof(x)

  OrderedField* = concept x, y
    x + y is typeof(x)
    x - y is typeof(x)
    x * y is typeof(x)
    x / y is typeof(x)
    -x is typeof(x)
    fromInt(typeof(x), 1) is typeof(x)
    x < y is bool
    x <= y is bool

  RealField* = concept x, y
    ## An `OrderedField` that also supports the two real-valued operations a
    ## Euclidean norm needs: `sqrt` (vector `length`) and `abs` (tolerance
    ## comparisons). Satisfied by `float32`/`float64`, `BigFloat`, `Rational`,
    ## and `Fixed`. It is the scalar contract a Euclidean-vector type
    ## constrains on for `length`, refined further with `sin`/`cos` for
    ## rotations in a geometry library. `sqrt` is
    ## required here rather than in `OrderedField` because summation/EFT code
    ## needs the ordered field without demanding a root, and because `sqrt` is
    ## total only on the non-negative inputs a squared length always produces.
    ##
    ## The `OrderedField` requirements are spelled out rather than nested as
    ## `x is OrderedField`: a concept-in-concept trips "too nested for type
    ## matching" when `RealField` constrains a generic proc instantiated inside
    ## other templates (e.g. a `Vector[D, T]` op under a test's `suite`).
    x + y is typeof(x)
    x - y is typeof(x)
    x * y is typeof(x)
    x / y is typeof(x)
    -x is typeof(x)
    fromInt(typeof(x), 1) is typeof(x)
    x < y is bool
    x <= y is bool
    sqrt(x) is typeof(x)
    abs(x) is typeof(x)

  Integer* = concept x, y
    x < y is bool
    x <= y is bool
    x == y is bool
    x != y is bool
    x > y is bool
    x >= y is bool
    x + y is typeof(x)
    x - y is typeof(x)
    x div y is typeof(x)
    x shl 2 is typeof(x)
    x shr 2 is typeof(x)
    default(typeof(x)) is typeof(x)
