# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import pytest

from unimath import Rational


def test_from_int_pair():
    assert Rational(1, 2).to_f64() == 0.5
    assert Rational(1, 3).to_f64() == 1.0 / 3.0
    assert Rational(3).to_f64() == 3.0  # den defaults to 1


def test_reduces():
    r = Rational(4, 8)
    assert r.to_f64() == 0.5
    assert str(r.numerator()) == "1"
    assert str(r.denominator()) == "2"


def test_sign_in_numerator():
    r = Rational(1, -2)
    assert r.to_f64() == -0.5
    assert str(r.numerator()) == "-1"
    assert str(r.denominator()) == "2"


def test_arithmetic():
    a = Rational(1, 2)
    b = Rational(1, 3)
    assert (a + b).to_f64() == 5.0 / 6.0
    assert (a - b).to_f64() == 1.0 / 6.0
    assert (a * b).to_f64() == 1.0 / 6.0
    assert (a / b).to_f64() == 1.5


def test_neg_abs():
    assert (-Rational(3, 4)).to_f64() == -0.75
    assert abs(Rational(-3, 4)).to_f64() == 0.75


def test_comparison():
    a = Rational(1, 2)
    b = Rational(1, 3)
    assert a > b
    assert b < a
    assert a == Rational(2, 4)
    assert a != b


def test_copy_is_exact():
    a = Rational(6, 9)  # reduces to 2/3
    c = Rational(a)
    assert str(c.numerator()) == "2"
    assert str(c.denominator()) == "3"
    assert c == a


def test_zero_denominator_raises():
    with pytest.raises(ZeroDivisionError):
        Rational(1, 0)


def test_div_by_zero_raises():
    with pytest.raises(ZeroDivisionError):
        Rational(1, 2) / Rational(0, 1)


def test_str_repr():
    assert str(Rational(1, 2)) == "1/2"
    assert repr(Rational(1, 2)) == "Rational(1, 2)"


def test_is_zero_is_one():
    assert Rational(0, 1).is_zero()
    assert not Rational(1, 2).is_zero()
    assert Rational(1, 1).is_one()
    assert not Rational(1, 2).is_one()

