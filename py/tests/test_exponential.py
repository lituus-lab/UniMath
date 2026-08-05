# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

from unimath import Exponential, BigFloat


def test_exp():
    assert abs(Exponential.exp(0.0) - 1.0) < 1e-12
    assert abs(Exponential.exp(1.0) - math.e) < 1e-6
    assert abs(Exponential.exp(-1.0) - 1.0 / math.e) < 1e-6


def test_ln_1px():
    assert abs(Exponential.ln_1px(0.0) - 0.0) < 1e-12
    # 15-term alternating series at |x|=0.5 converges to ~1e-5
    assert abs(Exponential.ln_1px(0.5) - math.log(1.5)) < 1e-4


def test_ln_1px_domain_is_nan():
    assert math.isnan(Exponential.ln_1px(-1.0))


def test_ln():
    assert abs(Exponential.ln(1.0) - 0.0) < 1e-12
    assert abs(Exponential.ln(math.e) - 1.0) < 1e-6
    assert abs(Exponential.ln(2.0) - math.log(2.0)) < 1e-6


def test_ln_domain_is_nan():
    assert math.isnan(Exponential.ln(0.0))
    assert math.isnan(Exponential.ln(-1.0))


def test_exp_ln_bigfloat_round_trip():
    z = BigFloat(2.0)
    lnz = Exponential.ln_bigfloat(z)
    assert abs(float(lnz) - math.log(2.0)) < 1e-10
    back = Exponential.exp_bigfloat(lnz)
    assert abs(float(back) - 2.0) < 1e-10


def test_ln_bigfloat_domain_raises():
    import pytest
    with pytest.raises(ValueError):
        Exponential.ln_bigfloat(BigFloat(0.0))
    with pytest.raises(ValueError):
        Exponential.ln_bigfloat(BigFloat(-1.0))
