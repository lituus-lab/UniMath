# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniMath — umbrella module. Re-exports every public submodule.
import ./UniMath/arithmetic
import ./UniMath/fixed
import ./UniMath/float
import ./UniMath/rational
import ./UniMath/interval
import ./UniMath/complex
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
import ./UniMath/native_float
import ./UniMath/complex_math
export arithmetic, fixed, float, rational, interval, complex, eft, roots,
       exponential, trigonometry, hyperbolic, special, constants, reduction,
       float_math, rational_math, conversions, math_router, native_float, 
			 complex_math

const UniMathVersion* = "1.0.0"
