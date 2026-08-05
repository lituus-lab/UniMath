# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

from unimath import Hyperbolic


def test_cordic_sinh_cosh_exp_at_zero():
    h = Hyperbolic()
    assert abs(h.sinh(0.0) - 0.0) < 1e-3
    assert abs(h.cosh(0.0) - 1.0) < 1e-3
    assert abs(h.exp(0.0) - 1.0) < 1e-3


def test_cordic_sinh_cosh_tanh_exp_at_one():
    h = Hyperbolic()
    assert abs(h.sinh(1.0) - math.sinh(1.0)) < 1e-3
    assert abs(h.cosh(1.0) - math.cosh(1.0)) < 1e-3
    assert abs(h.tanh(1.0) - math.tanh(1.0)) < 1e-3
    assert abs(h.exp(1.0) - math.exp(1.0)) < 1e-3


def test_cordic_exp_out_of_domain_is_clamped_not_raised():
    # 2.0 exceeds the ~1.1182 CORDIC budget; the C ABI clamps to the boundary
    # (exp(1.10)) instead of raising.
    h = Hyperbolic()
    val = h.exp(2.0)
    assert abs(val - math.exp(1.10)) < 0.2
