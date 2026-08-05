# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

from unimath import Trigonometry


def test_taylor_sin_cos_atan():
    assert abs(Trigonometry.sin(0.0) - 0.0) < 1e-12
    assert abs(Trigonometry.cos(0.0) - 1.0) < 1e-12
    assert abs(Trigonometry.sin(0.5) - math.sin(0.5)) < 1e-6
    assert abs(Trigonometry.cos(0.5) - math.cos(0.5)) < 1e-6
    assert abs(Trigonometry.atan(0.5) - math.atan(0.5)) < 1e-6


def test_cordic_sin_cos():
    t = Trigonometry()
    assert abs(t.cordic_sin(0.0) - 0.0) < 1e-3
    assert abs(t.cordic_cos(0.0) - 1.0) < 1e-3
    assert abs(t.cordic_sin(0.5) - math.sin(0.5)) < 1e-3
    assert abs(t.cordic_cos(0.5) - math.cos(0.5)) < 1e-3


def test_cordic_atan2():
    t = Trigonometry()
    assert abs(t.cordic_atan2(1.0, 1.0) - math.pi / 4) < 1e-3
    assert abs(t.cordic_atan2(1.0, -1.0) - 3 * math.pi / 4) < 1e-3


def test_lut_sin_cos():
    t = Trigonometry()
    assert abs(t.lut_sin(0.0) - 0.0) < 0.02
    assert abs(t.lut_cos(0.0) - 1.0) < 0.02
    assert abs(t.lut_sin(0.5) - math.sin(0.5)) < 0.02


def test_chebyshev_tan():
    t = Trigonometry()
    assert abs(t.chebyshev_tan(0.0) - 0.0) < 1e-3
    assert abs(t.chebyshev_tan(0.5) - math.tan(0.5)) < 1e-3
