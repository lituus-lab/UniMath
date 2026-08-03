# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Special sub-umbrella: orthogonal polynomials (Chebyshev T/U, Legendre,
## Hermite), the error function, the Gamma function and integer combinatorics,
## and the Bessel `J0`. Cross-package imports go through this single module;
## special sits above hyperbolic in the internal layer DAG.
import ./special/polynomials
import ./special/error_functions
import ./special/gamma
import ./special/bessel
export polynomials, error_functions, gamma, bessel
