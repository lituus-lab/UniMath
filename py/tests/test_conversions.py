# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

import pytest

from unimath import BigInt, BigFloat, Fixed, Rational, Conversions


@pytest.fixture
def cv():
    return Conversions()


def test_rational_from_f64_exact(cv):
    r = cv.rational_from_f64(0.5)
    assert r is not None
    assert r.to_f64() == 0.5


def test_rational_from_f64_nan_inf_clamps_to_none(cv):
    assert cv.rational_from_f64(float("nan")) is None
    assert cv.rational_from_f64(float("inf")) is None


def test_rational_from_fixed(cv):
    r = cv.rational_from_fixed(Fixed(2.5, 32), 32)
    assert r is not None
    assert r.to_f64() == 2.5


def test_bigfloat_from_rational(cv):
    bf = cv.bigfloat_from_rational(Rational(1, 3))
    assert bf is not None
    assert abs(bf.to_f64() - 1.0 / 3.0) < 1e-6


def test_bigint_from_bigfloat(cv):
    assert str(cv.bigint_from_bigfloat(BigFloat(42.75))) == "42"
    assert str(cv.bigint_from_bigfloat(BigFloat(-42.75))) == "-42"


def test_bigint_from_rational(cv):
    assert str(cv.bigint_from_rational(Rational(7, 2))) == "3"
    assert str(cv.bigint_from_rational(Rational(-7, 2))) == "-3"


def test_fixed_from_rational(cv):
    f = cv.fixed_from_rational(Rational(1, 3), 32)
    assert abs(f.value() - 1.0 / 3.0) < 2.0 ** -31
    assert f.value() <= 1.0 / 3.0  # truncation toward zero


def test_interval_from_bigfloat(cv):
    i = cv.interval_from_bigfloat(BigFloat(2.5))
    assert i.lo <= 2.5 <= i.hi


def test_interval_from_rational(cv):
    i = cv.interval_from_rational(Rational(1, 3))
    assert i.lo <= 1.0 / 3.0 <= i.hi


def test_interval_from_bigint(cv):
    i = cv.interval_from_bigint(BigInt(123456789))
    assert i.lo <= 123456789.0 <= i.hi
