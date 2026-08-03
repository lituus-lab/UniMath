# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

import pytest

from unimath import BigFloat


def test_from_float_roundtrip():
    assert BigFloat(1.5).to_f64() == 1.5
    assert BigFloat(-0.125).to_f64() == -0.125
    assert float(BigFloat(3.0)) == 3.0


def test_from_int_is_exact():
    # 2^60 is exactly representable; from_i64 takes the exact BigInt path.
    assert BigFloat(1 << 60).to_f64() == float(1 << 60)


def test_arithmetic():
    a = BigFloat(10.0)
    b = BigFloat(3.0)
    assert (a + b).to_f64() == 13.0
    assert (a - b).to_f64() == 7.0
    assert (a * b).to_f64() == 30.0
    assert abs((a / b).to_f64() - 10.0 / 3.0) < 1e-12


def test_negation():
    assert (-BigFloat(4.0)).to_f64() == -4.0


def test_comparison():
    a = BigFloat(3.0)
    b = BigFloat(5.0)
    assert a < b
    assert b > a
    assert a == BigFloat(3.0)
    assert a != b
    assert a <= a
    assert b >= a


def test_div_by_zero_raises():
    with pytest.raises(ZeroDivisionError):
        _ = BigFloat(7.0) / BigFloat(0.0)


def test_inf_and_nan_rejected():
    with pytest.raises(ValueError):
        BigFloat(math.inf)
    with pytest.raises(ValueError):
        BigFloat(math.nan)


def test_overflow_to_inf():
    huge = BigFloat(1e308) * BigFloat(1e308)
    assert math.isinf(huge.to_f64())
