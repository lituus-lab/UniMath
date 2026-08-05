# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

from unimath import Reduction


def test_reduce_mod_two_pi():
    r = Reduction()
    assert abs(r.reduce(2.0 * math.pi + 0.5) - 0.5) < 1e-12
    assert abs(r.reduce(0.5) - 0.5) < 1e-12
    assert abs(r.reduce(math.pi + 0.1) - (-math.pi + 0.1)) < 1e-12
