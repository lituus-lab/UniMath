# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

import pytest

from unimath import MathRouter


@pytest.fixture
def mr():
    return MathRouter()


def test_sin_cos(mr):
    assert abs(mr.sin(0.0)) < 1e-3
    assert abs(mr.cos(0.0) - 1.0) < 1e-3
    assert abs(mr.sin(0.5) - math.sin(0.5)) < 1e-3
    assert abs(mr.cos(0.5) - math.cos(0.5)) < 1e-3


def test_tan(mr):
    assert abs(mr.tan(0.5) - math.tan(0.5)) < 1e-3


def test_exp_ln(mr):
    assert abs(mr.exp(0.0) - 1.0) < 1e-3
    assert abs(mr.exp(1.0) - math.e) < 1e-3
    assert abs(mr.ln(1.0)) < 1e-4
    assert abs(mr.ln(1.5) - math.log(1.5)) < 1e-4


def test_sqrt(mr):
    assert abs(mr.sqrt(4.0) - 2.0) < 1e-6
    assert abs(mr.sqrt(2.0) - math.sqrt(2.0)) < 1e-6


def test_atan_atan2(mr):
    assert abs(mr.atan(1.0) - math.pi / 4) < 1e-3
    assert abs(mr.atan2(1.0, 1.0) - math.pi / 4) < 1e-3


def test_hyperbolic(mr):
    assert abs(mr.sinh(1.0) - math.sinh(1.0)) < 1e-3
    assert abs(mr.cosh(1.0) - math.cosh(1.0)) < 1e-3
    assert abs(mr.tanh(1.0) - math.tanh(1.0)) < 1e-3


def test_pow(mr):
    assert abs(mr.pow(1.5, 1.0) - 1.5) < 2e-2


def test_inverse_trig(mr):
    assert abs(mr.asin(0.5) - math.asin(0.5)) < 2e-2
    assert abs(mr.acos(0.5) - math.acos(0.5)) < 2e-2
    assert mr.asin(2.0) == 0.0


def test_domain_clamps_to_zero(mr):
    # The C ABI never raises: ln(<=0), sqrt(<0), and out-of-convergence exp
    # (|z| > ~1.1182) clamp to 0.0.
    assert mr.ln(0.0) == 0.0
    assert mr.sqrt(-1.0) == 0.0
    assert mr.exp(2.0) == 0.0
