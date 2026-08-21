# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

from unimath import NativeFloat


def test_roots_logs_and_exponentials():
    assert NativeFloat.sqrt(4.0) == 2.0
    # libm cbrt is not correctly rounded everywhere: glibc returns 3.0 + 1 ulp.
    assert abs(NativeFloat.cbrt(27.0) - 3.0) < 1e-15
    assert math.isnan(NativeFloat.sqrt(-1.0))
    assert NativeFloat.ln(1.0) == 0.0
    assert NativeFloat.log(8.0, 2.0) == 3.0
    assert NativeFloat.log2(8.0) == 3.0
    assert NativeFloat.log10(1000.0) == 3.0
    assert abs(NativeFloat.log1p(1e-16) - 1e-16) < 1e-31
    assert abs(NativeFloat.exp(1.0) - math.e) < 1e-15
    assert abs(NativeFloat.expm1(1e-16) - 1e-16) < 1e-31
    assert NativeFloat.pow(2.0, 10.0) == 1024.0


def test_trigonometry_and_hypotenuse():
    assert NativeFloat.sin(0.0) == 0.0
    assert NativeFloat.cos(0.0) == 1.0
    sine, cosine = NativeFloat.sin_cos(math.pi / 4.0)
    assert sine == NativeFloat.sin(math.pi / 4.0)
    assert cosine == NativeFloat.cos(math.pi / 4.0)
    assert abs(NativeFloat.tan(math.pi / 4.0) - 1.0) < 1e-15
    assert NativeFloat.arcsin(0.0) == 0.0
    assert NativeFloat.arccos(1.0) == 0.0
    assert NativeFloat.arctan(0.0) == 0.0
    assert NativeFloat.arctan2(1.0, 0.0) == NativeFloat.atan2(1.0, 0.0)
    assert abs(NativeFloat.atan2(1.0, 0.0) - math.pi / 2.0) < 1e-15
    assert NativeFloat.hypot(3.0, 4.0) == 5.0
    assert math.isfinite(NativeFloat.hypot(1e308, 1e308))


def test_hyperbolic_special_and_rounding():
    assert NativeFloat.sinh(0.0) == 0.0
    assert NativeFloat.cosh(0.0) == 1.0
    assert NativeFloat.tanh(0.0) == 0.0
    assert NativeFloat.arcsinh(0.0) == 0.0
    assert NativeFloat.arccosh(1.0) == 0.0
    assert NativeFloat.arctanh(0.0) == 0.0
    assert NativeFloat.erf(0.0) == 0.0
    assert NativeFloat.erfc(0.0) == 1.0
    assert NativeFloat.gamma(5.0) == 24.0
    assert abs(NativeFloat.lgamma(5.0) - math.log(24.0)) < 1e-15
    assert abs(NativeFloat.log_beta(2.0, 3.0) - math.log(1.0 / 12.0)) < 2e-15
    assert abs(NativeFloat.beta(2.0, 3.0) - 1.0 / 12.0) < 2e-16
    assert abs(
        NativeFloat.regularized_incomplete_beta(0.2, 2.0, 5.0)
        - 0.34464000000000006
    ) < 2e-14
    assert math.isnan(NativeFloat.log_beta(0.0, 1.0))
    assert math.isnan(NativeFloat.beta(1.0, math.inf))
    assert math.isnan(NativeFloat.regularized_incomplete_beta(-0.1, 1.0, 1.0))
    assert math.isnan(NativeFloat.beta(1e308, 1e308))
    assert NativeFloat.MAX_REGULARIZED_BETA_SHAPE_SUM == 200_000.0
    assert math.isnan(
        NativeFloat.regularized_incomplete_beta(
            0.5, NativeFloat.MAX_REGULARIZED_BETA_SHAPE_SUM, 2.0
        )
    )
    assert NativeFloat.floor(1.75) == 1.0
    assert NativeFloat.ceil(1.25) == 2.0
    assert NativeFloat.trunc(-1.75) == -1.0
    assert NativeFloat.round(1.6) == 2.0
    assert NativeFloat.round(1.234, 2) == 1.23


def test_decomposition_classification_and_helpers():
    assert NativeFloat.copy_sign(1.0, -0.0) == -1.0
    assert NativeFloat.next_after(1.0, 2.0) > 1.0
    assert NativeFloat.deg_to_rad(180.0) == math.pi
    assert NativeFloat.rad_to_deg(math.pi) == 180.0
    integer, fraction = NativeFloat.split_decimal(-1.25)
    assert integer == -1.0
    assert fraction == -0.25
    integer, fraction = NativeFloat.split_decimal(-0.0)
    assert math.copysign(1.0, integer) == -1.0
    assert math.copysign(1.0, fraction) == -1.0
    assert NativeFloat.frexp(8.0) == (0.5, 4)
    assert NativeFloat.signbit(-0.0)
    assert NativeFloat.classify(1.0) == NativeFloat.NORMAL
    assert NativeFloat.classify(-0.0) == NativeFloat.NEG_ZERO
    assert NativeFloat.classify(math.nan) == NativeFloat.NAN
    assert NativeFloat.almost_equal(1.0, NativeFloat.next_after(1.0, 2.0), 1)
    assert not NativeFloat.almost_equal(1.0, 2.0, -1)


def test_non_finite_classifications():
    assert NativeFloat.exp(math.inf) == math.inf
    assert NativeFloat.hypot(math.inf, 1.0) == math.inf
    assert math.isnan(NativeFloat.sin(math.inf))
    assert math.isnan(NativeFloat.atan2(math.nan, 1.0))
