# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniMath — umbrella module. Re-exports every public submodule.
import ./UniMath/arithmetic
import ./UniMath/fixed
import ./UniMath/float
import ./UniMath/rational
import ./UniMath/interval
import ./UniMath/eft
import ./UniMath/roots
import ./UniMath/exponential
import ./UniMath/trigonometry
import ./UniMath/hyperbolic
import ./UniMath/special
import ./UniMath/constants
import ./UniMath/reduction
import ./UniMath/float_math
import ./UniMath/rational_math
import ./UniMath/conversions
import ./UniMath/math_router
export arithmetic, fixed, float, rational, interval, eft, roots, exponential,
       trigonometry, hyperbolic, special, constants, reduction, float_math,
       rational_math, conversions, math_router

const UniMathVersion* = "0.1.0"
