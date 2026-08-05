# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Roots sub-umbrella: integer square root and the generic Newton-Raphson
## square root. Cross-package imports go through this single module; roots
## sits above arithmetic (concepts) and eft in the internal layer DAG.
##
## It also re-exports the hardware `sqrt` for `float32`/`float64` from
## `std/math`, so that `import UniMath` alone supplies `sqrt` for every scalar
## the `RealField` concept accepts — floats via the hardware root here, the
## exact types via their own overloads (`float_math`, `rational_math`,
## `math_router`). Without this, generic `RealField` code (e.g. a float
## `Vector[D, T].length`) would fail unless the caller also imported std/math.
import std/math
import ./roots/isqrt
import ./roots/sqrt_newton
export math.sqrt
export isqrt, sqrt_newton
