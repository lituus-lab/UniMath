# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import cmath
import math

import pytest

import unimath as u


# --- promotion: a dynamic front-end can pick the return type per value -----


def test_sqrt_of_a_negative_promotes_to_complex():
    assert u.sqrt(-1) == 1j
    assert u.sqrt(-4) == 2j


def test_sqrt_of_a_non_negative_stays_real():
    assert u.sqrt(4) == 2.0
    assert isinstance(u.sqrt(4), float)
    assert u.sqrt(2) == pytest.approx(math.sqrt(2))
    assert u.sqrt(0) == 0.0


def test_sqrt_of_a_complex_stays_complex():
    assert u.sqrt(-1 + 0j) == pytest.approx(1j)
    assert u.sqrt(3 + 4j) == pytest.approx(2 + 1j)


def test_log_promotes_on_the_negative_side():
    assert u.log(-1) == pytest.approx(math.pi * 1j)
    assert u.log(1) == 0.0
    assert isinstance(u.log(1), float)
    assert u.log(math.e) == pytest.approx(1.0)


def test_log_of_zero_raises_like_math_log():
    with pytest.raises(ValueError):
        u.log(0)


# --- float64 complex, in and out as Python's builtin complex ----------------


@pytest.fixture
def cm():
    return u.ComplexMath()


def test_arithmetic_matches_python(cm):
    a, b = 1 + 2j, 3 - 1j
    assert cm.add(a, b) == a + b
    assert cm.sub(a, b) == a - b
    assert cm.mul(a, b) == a * b
    assert cm.div(a, b) == pytest.approx(a / b)
    assert cm.neg(a) == -a
    assert cm.conj(a) == a.conjugate()
    assert cm.inv(a) == pytest.approx(1 / a)


def test_modulus_and_argument(cm):
    assert cm.abs(3 + 4j) == 5.0
    assert cm.norm2(3 + 4j) == 25.0
    assert cm.arg(-1 + 0j) == pytest.approx(math.pi)
    r, theta = cm.polar(1.5 - 2.5j)
    assert cm.rect(r, theta) == pytest.approx(1.5 - 2.5j)


def test_division_survives_a_squared_magnitude_overflow(cm):
    # norm2 of either operand is +Inf, so the textbook formula gives NaN.
    assert cm.div(complex(1e300, 1e300), complex(1e300, 1e300)) == 1 + 0j
    assert math.isfinite(cm.abs(complex(1e300, 1e300)))


def test_transcendentals_agree_with_cmath(cm):
    z = 1 + 1j
    assert cm.sqrt(z) == pytest.approx(cmath.sqrt(z))
    assert cm.exp(z) == pytest.approx(cmath.exp(z))
    assert cm.ln(z) == pytest.approx(cmath.log(z))
    assert cm.sin(z) == pytest.approx(cmath.sin(z))
    assert cm.cos(z) == pytest.approx(cmath.cos(z))
    assert cm.tan(z) == pytest.approx(cmath.tan(z))
    assert cm.sinh(z) == pytest.approx(cmath.sinh(z))
    assert cm.cosh(z) == pytest.approx(cmath.cosh(z))
    assert cm.tanh(z) == pytest.approx(cmath.tanh(z))


def test_the_branch_cut_is_the_principal_one(cm):
    assert cm.sqrt(-3 + 4j) == pytest.approx(cmath.sqrt(-3 + 4j))
    assert cm.sqrt(-3 - 4j) == pytest.approx(cmath.sqrt(-3 - 4j))
    assert cm.ln(-1 + 0j) == pytest.approx(cmath.log(-1 + 0j))


def test_powers(cm):
    z = 1 + 2j
    assert cm.pow_int(z, 3) == pytest.approx(z**3)
    assert cm.pow_int(z, -1) == pytest.approx(1 / z)
    assert cm.pow_int(0j, 0) == 1 + 0j
    assert cm.pow(z, 2 + 0j) == pytest.approx(z**2)
    assert cm.pow(1j, 1j).real == pytest.approx(math.exp(-math.pi / 2))


def test_domain_errors_return_none_not_raise(cm):
    assert cm.div(1 + 1j, 0j) is None
    assert cm.inv(0j) is None
    assert cm.ln(0j) is None
    assert cm.pow(0j, 2 + 0j) is None
    assert cm.pow_int(0j, -1) is None


# --- BigComplex: the multi-precision backend --------------------------------


def test_bigcomplex_arithmetic_and_modulus():
    z = u.BigComplex(3, 4)
    assert float(z.abs()) == pytest.approx(5.0)
    assert float(z.norm2()) == pytest.approx(25.0)
    assert float(z.re) == 3.0 and float(z.im) == 4.0
    a, b = u.BigComplex(1, 2), u.BigComplex(3, -1)
    assert complex(a * b) == pytest.approx(5 + 5j)
    assert complex((a * b) / b) == pytest.approx(1 + 2j)
    assert complex(-a) == pytest.approx(-1 - 2j)
    assert complex(a.conj()) == pytest.approx(1 - 2j)


def test_bigcomplex_transcendentals_and_branch_cut():
    assert complex(u.BigComplex(0, math.pi).exp()) == pytest.approx(-1 + 0j, abs=1e-12)
    assert complex(u.BigComplex(-1, 0).ln()) == pytest.approx(math.pi * 1j, abs=1e-12)
    assert complex(u.BigComplex(-3, -4).sqrt()) == pytest.approx(1 - 2j, abs=1e-12)
    assert complex(u.BigComplex(0, 1) ** 2) == pytest.approx(-1 + 0j, abs=1e-12)
    assert float(u.BigComplex(-1, 0).arg()) == pytest.approx(math.pi)


def test_bigcomplex_domain_errors_raise():
    with pytest.raises(ZeroDivisionError):
        u.BigComplex(1, 0) / u.BigComplex(0, 0)
    with pytest.raises(ValueError):
        u.BigComplex(0, 0).ln()
    assert u.BigComplex(0, 0).is_zero()


def test_sqrt_promotes_a_bigfloat_to_a_bigcomplex():
    r = u.sqrt(u.BigFloat(-1.0))
    assert isinstance(r, u.BigComplex)
    assert complex(r) == pytest.approx(1j)
    assert isinstance(u.sqrt(u.BigFloat(4.0)), u.BigFloat)
    assert float(u.sqrt(u.BigFloat(4.0))) == pytest.approx(2.0)


# --- RationalComplex: the exact backend -------------------------------------


def test_rationalcomplex_is_exact():
    z = u.RationalComplex(u.Rational(1, 2), u.Rational(3, 4))
    # norm2 is exact: (1/2)^2 + (3/4)^2 = 13/16
    n2 = z.norm2()
    assert (int(str(n2.numerator())), int(str(n2.denominator()))) == (13, 16)
    # z^2 = -5/16 + 3/4 i, exactly
    sq = z**2
    assert (int(str(sq.re.numerator())), int(str(sq.re.denominator()))) == (-5, 16)
    assert (int(str(sq.im.numerator())), int(str(sq.im.denominator()))) == (3, 4)
    # z * conj(z) == norm2, and z / z == 1, both exact
    p = z * z.conj()
    assert (int(str(p.re.numerator())), int(str(p.re.denominator()))) == (13, 16)
    assert p.im.is_zero()
    assert (z / z).re.is_one()


def test_rationalcomplex_stays_exact_past_int64():
    big = 10**12
    z = u.RationalComplex(u.Rational(big), u.Rational(big))
    sq = z**2  # (a + ai)^2 = 2a^2 i
    assert sq.re.is_zero()
    assert int(str(sq.im.numerator())) == 2 * big * big
    assert int(str(sq.im.denominator())) == 1


def test_rationalcomplex_domain_errors_raise():
    with pytest.raises(ZeroDivisionError):
        u.RationalComplex(1, 0) / u.RationalComplex(0, 0)
    with pytest.raises(TypeError):
        u.RationalComplex(1, 0) ** 0.5


def test_sqrt_promotes_a_rational_to_a_rationalcomplex():
    r = u.sqrt(u.Rational(-1))
    assert isinstance(r, u.RationalComplex)
    # The magnitude is a Newton iterate; which axis it lands on is exact.
    assert r.re.is_zero()
    assert complex(r).imag == pytest.approx(1.0, abs=1e-6)


# --- FixedComplex: the raw Q-format backend ---------------------------------


def test_fixedcomplex_arithmetic():
    a = u.FixedComplex(1, 2)
    b = u.FixedComplex(3, -1)
    assert a.raw_re == 1 << 32 and a.raw_im == 2 << 32
    assert complex(a + b) == pytest.approx(4 + 1j)
    assert complex(a * b) == pytest.approx(5 + 5j)
    assert complex((a * b) / b) == pytest.approx(1 + 2j)
    assert complex(-a) == pytest.approx(-1 - 2j)
    assert complex(a.conj()) == pytest.approx(1 - 2j)


def test_fixedcomplex_modulus_and_root():
    z = u.FixedComplex(3, 4)
    assert z.abs() == pytest.approx(5.0, abs=1e-6)
    assert z.norm2() == pytest.approx(25.0, abs=1e-6)
    assert u.FixedComplex(-1, 0).arg() == pytest.approx(math.pi, abs=1e-6)
    assert complex(u.FixedComplex(0, 1) ** 2) == pytest.approx(-1 + 0j, abs=1e-6)
    assert complex(u.FixedComplex(-3, -4).sqrt()) == pytest.approx(1 - 2j, abs=1e-6)


def test_fixedcomplex_rejects_a_frac_bits_mismatch():
    with pytest.raises(ValueError):
        u.FixedComplex(1, 0, 32) + u.FixedComplex(1, 0, 16)
    with pytest.raises(ZeroDivisionError):
        u.FixedComplex(1, 0) / u.FixedComplex(0, 0)


def test_sqrt_promotes_a_fixed_to_a_fixedcomplex():
    r = u.sqrt(u.Fixed(-1, 32))
    assert isinstance(r, u.FixedComplex)
    assert complex(r).imag == pytest.approx(1.0, abs=1e-6)
    assert isinstance(u.sqrt(u.Fixed(4, 32)), u.Fixed)
