# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

import pytest

from unimath import FloatMath


@pytest.fixture
def fm():
    return FloatMath()


def test_sin_cos(fm):
    assert fm.sin(0.0) == 0.0
    assert abs(fm.cos(0.0) - 1.0) < 1e-12
    assert abs(fm.sin(math.pi / 2) - 1.0) < 1e-12
    assert abs(fm.cos(math.pi / 2)) < 1e-12


def test_sin2_cos2(fm):
    for x in [0.3, 0.7, 1.1, 2.0, 3.0]:
        s = fm.sin(x)
        c = fm.cos(x)
        assert abs(s * s + c * c - 1.0) < 1e-12


def test_exp_ln(fm):
    assert fm.exp(0.0) == 1.0
    assert abs(fm.ln(1.0)) < 1e-12
    assert abs(fm.exp(1.0) - math.e) < 1e-12
    assert abs(fm.ln(math.e) - 1.0) < 1e-12
    for x in [0.5, 1.0, 2.0, 5.0]:
        assert abs(fm.exp(x) * fm.exp(-x) - 1.0) < 1e-12
        assert abs(fm.ln(fm.exp(x)) - x) < 1e-12


def test_sqrt(fm):
    assert abs(fm.sqrt(4.0) - 2.0) < 1e-12
    assert abs(fm.sqrt(2.0) - math.sqrt(2.0)) < 1e-12
    for x in [2.0, 3.0, 9.0, 0.25]:
        assert abs(fm.sqrt(x) * fm.sqrt(x) - x) < 1e-12


def test_arctan_arctan2(fm):
    assert abs(fm.arctan(1.0) - math.pi / 4) < 1e-12
    assert abs(fm.arctan2(1.0, 1.0) - math.pi / 4) < 1e-12
    assert abs(fm.arctan2(1.0, 0.0) - math.pi / 2) < 1e-12
    assert abs(fm.arctan2(0.0, -1.0) - math.pi) < 1e-12


def test_pow(fm):
    assert abs(fm.pow_int(2.0, 10) - 1024.0) < 1e-9
    assert fm.pow_int(3.0, 0) == 1.0
    assert abs(fm.pow(2.0, 0.5) - math.sqrt(2.0)) < 1e-12


def test_domain_errors_return_none(fm):
    assert fm.ln(0.0) is None
    assert fm.ln(-1.0) is None
    assert fm.sqrt(-1.0) is None
    assert fm.pow(-1.0, 0.5) is None
