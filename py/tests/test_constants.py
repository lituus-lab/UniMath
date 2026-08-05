# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

from unimath import Constants


def test_pi_e_bigfloat_float64_exact():
    c = Constants()
    assert abs(c.pi_bigfloat() - math.pi) < 1e-15
    assert abs(c.e_bigfloat() - math.e) < 1e-15


def test_pi_e_fixed_q32():
    c = Constants()
    assert abs(c.pi_fixed() - math.pi) < 2.0 ** -32
    assert abs(c.e_fixed() - math.e) < 2.0 ** -32
