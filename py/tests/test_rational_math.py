# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

import pytest

from unimath import Rational, RationalMath


@pytest.fixture
def rm():
    return RationalMath()


def test_sin_cos(rm):
    assert float(rm.sin(Rational(0, 1))) == 0.0
    assert abs(float(rm.cos(Rational(0, 1))) - 1.0) < 1e-12
    assert abs(float(rm.sin(Rational(1, 4))) - math.sin(0.25)) < 1e-9
    assert abs(float(rm.cos(Rational(1, 4))) - math.cos(0.25)) < 1e-9


def test_exp_ln(rm):
    assert float(rm.exp(Rational(0, 1))) == 1.0
    assert abs(float(rm.ln(Rational(1, 1)))) < 1e-9
    assert abs(float(rm.exp(Rational(1, 4))) - math.exp(0.25)) < 1e-9
    assert abs(float(rm.ln(Rational(2, 1))) - math.log(2.0)) < 1e-9


def test_sqrt(rm):
    assert abs(float(rm.sqrt(Rational(4, 1))) - 2.0) < 1e-9
    assert abs(float(rm.sqrt(Rational(2, 1))) - math.sqrt(2.0)) < 1e-6


def test_atan_atan2(rm):
    assert abs(float(rm.atan(Rational(1, 3))) - math.atan(1.0 / 3.0)) < 1e-5
    assert abs(float(rm.atan2(Rational(1, 1), Rational(3, 1))) -
               math.atan(1.0 / 3.0)) < 1e-5


def test_pow(rm):
    assert abs(float(rm.pow(Rational(2, 1), Rational(1, 2))) -
               math.sqrt(2.0)) < 1e-6


def test_domain_errors_return_none(rm):
    assert rm.ln(Rational(0, 1)) is None
    assert rm.ln(Rational(-1, 1)) is None
    assert rm.sqrt(Rational(-1, 1)) is None
    assert rm.pow(Rational(-1, 1), Rational(1, 2)) is None
