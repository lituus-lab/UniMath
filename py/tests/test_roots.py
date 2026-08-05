# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

from unimath import Roots, BigFloat


def test_isqrt():
    assert Roots.isqrt(0) == 0
    assert Roots.isqrt(1) == 1
    assert Roots.isqrt(3) == 1
    assert Roots.isqrt(4) == 2
    assert Roots.isqrt(15) == 3
    assert Roots.isqrt(16) == 4
    assert Roots.isqrt(1_000_000) == 1000


def test_isqrt_negative_clamps_to_zero():
    assert Roots.isqrt(-1) == 0


def test_sqrt_newton_f64():
    assert abs(Roots.sqrt_newton(4.0) - 2.0) < 1e-12
    assert abs(Roots.sqrt_newton(2.0) - math.sqrt(2.0)) < 1e-12
    assert Roots.sqrt_newton(0.0) == 0.0


def test_sqrt_newton_f64_negative_is_nan():
    assert math.isnan(Roots.sqrt_newton(-1.0))


def test_sqrt_newton_bigfloat():
    s = Roots.sqrt_newton_bigfloat(BigFloat(4.0))
    assert abs(float(s) - 2.0) < 1e-20
    z = Roots.sqrt_newton_bigfloat(BigFloat(0.0))
    assert float(z) == 0.0


def test_sqrt_newton_bigfloat_negative_raises():
    import pytest
    with pytest.raises(ValueError):
        Roots.sqrt_newton_bigfloat(BigFloat(-4.0))
