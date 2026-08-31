# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, strformat]
import lituus_theme
import UniMath

nbInit(theme = useNimibook)
useLituus()
nb.title = "UniMath"

nbText: """
# UniMath

A multi-precision numeric library: arbitrary-precision integers, fixed-point,
big floats, rationals, intervals and complex numbers over any of those, with
the transcendental and special-function algorithms over them. Exposed across
three surfaces —
**Nim**, a **C ABI**, and a **Python** binding.

Every Nim block in this book is compiled and run when the book is built, and
the output shown is what the code produced. A change that breaks the API breaks
the docs build, so the two cannot drift apart.

## Who this book is for

Nim developers who need arithmetic beyond what `float64`/`int64` can represent
exactly or without overflow: exact fractions, correctly-rounded arbitrary
precision, or a guaranteed enclosure of a rounding error. No numerical-analysis
background is assumed — each section states what problem its type or algorithm
solves before showing it.

## How to read this book

Read top to bottom: each section only uses types and functions introduced
above it.

1. **Types** — BigInt, Fixed, BigFloat, Rational, Interval: the five ways
   this library represents a real number, and Complex, which pairs any two of
   them.
2. **EFT** — the error-free-transform primitive the analysis layer below
   is built on.
3. **Algorithms** — Roots, Exponential, Trigonometry, Hyperbolic, Special:
   one section per family of transcendental/special-function algorithm,
   each generic over the types above.
4. **Dispatch and integration** — Constants, Reduction, float_math,
   rational_math, conversions, math_router: how the algorithms above are
   assembled into the actual per-backend `sin`/`exp`/`sqrt`/... API and how
   values move between backends.

A reader only interested in one type or algorithm can jump straight to its
section: every code example is self-contained (imports and all), so nothing
earlier is required to run it.

## Notation

- `Fixed[T, FracBits]`: Q-format fixed-point — an integer of type `T` holding
  the real value scaled by `2^FracBits`. `Fixed[int64, 32]` is written
  `Q31.32` below: 64 storage bits, 32 fractional and one of sign leave **31**
  integer bits, so the range is `[-2^31, 2^31)` and a value under `2^32` can
  still overflow.
- `BigFloat`'s `precision` argument (e.g. `initBigFloat(2.0, 128)`) is the
  mantissa width in bits, not decimal digits; the default is 256.
- `rmNearest`/`rmUp`/`rmDown`: rounding modes — round to nearest, or round so
  the result is guaranteed `>=`/`<=` the exact value (used to build
  `Interval` enclosures).
- The C ABI never raises: invalid input clamps where explicitly documented
  (`Fixed`) or returns a sentinel (`NaN`, null handle) instead of an exception
  crossing the language boundary. Python value-only helpers mirror those C
  sentinels; higher-level Python objects raise where their API documents it.

## The Nim surface

The umbrella module re-exports every public submodule.
"""

nbCode:
  import UniMath

  echo "version ", UniMathVersion

nbText: """
"""

nbSave
