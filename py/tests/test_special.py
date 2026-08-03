# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

from unimath import Special


def test_orthogonal_polynomials():
    s = Special()
    assert abs(s.chebyshev_t(2, 0.5) - (-0.5)) < 1e-12
    assert abs(s.chebyshev_u(2, 0.5) - 0.0) < 1e-12
    assert abs(s.legendre(2, 0.5) - (-0.125)) < 1e-12
    assert abs(s.hermite(3, 0.5) - (-5.0)) < 1e-12


def test_erf_gamma_factorial_bessel():
    s = Special()
    assert abs(s.erf(0.0) - 0.0) < 1e-12
    assert 0.50 < s.erf(0.5) < 0.55
    assert abs(s.gamma(1.0) - 1.0) < 1e-10
    assert abs(s.gamma(5.0) - 24.0) < 1e-9
    assert abs(s.gamma(0.5) - math.sqrt(math.pi)) < 1e-10
    assert abs(s.factorial(5) - 120.0) < 1e-12
    assert s.factorial(-1) == 0.0
    assert abs(s.bessel_j0(0.0) - 1.0) < 1e-12
    assert 0.90 < s.bessel_j0(0.5) < 0.96


def test_gamma_poles_are_nan_not_raised():
    # The C ABI never raises: the non-positive-integer poles return nan.
    s = Special()
    assert math.isnan(s.gamma(0.0))
    assert math.isnan(s.gamma(-1.0))
