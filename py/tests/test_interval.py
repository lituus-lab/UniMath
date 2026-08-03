# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import math

from unimath import Interval


def test_construction():
    a = Interval(1.0, 2.0)
    assert a.lo == 1.0
    assert a.hi == 2.0
    d = Interval(3.0)  # degenerate
    assert d.lo == 3.0 and d.hi == 3.0


def test_arithmetic_encloses():
    a = Interval(1.0, 2.0)
    b = Interval(3.0, 4.0)
    s = a + b
    assert math.isfinite(s.lo) and math.isfinite(s.hi)
    assert s.lo <= 4.0 and s.hi >= 6.0 and s.lo <= s.hi
    d = a - b
    assert math.isfinite(d.lo) and math.isfinite(d.hi)
    assert d.lo <= -3.0 and d.hi >= -2.0
    m = Interval(2.0, 3.0) * Interval(4.0, 5.0)
    assert math.isfinite(m.lo) and math.isfinite(m.hi)
    assert m.lo <= 8.0 and m.hi >= 15.0
    q = Interval(6.0, 8.0) / Interval(2.0, 4.0)
    assert math.isfinite(q.lo) and math.isfinite(q.hi)
    assert q.lo <= 1.5 and q.hi >= 4.0


def test_div_by_uncertain_is_unbounded():
    r = Interval(1.0, 2.0) / Interval(-1.0, 1.0)
    assert math.isinf(r.lo) and r.lo < 0
    assert math.isinf(r.hi) and r.hi > 0


def test_sqrt():
    r = Interval(4.0, 9.0).sqrt()
    assert r.lo <= 2.0 and r.hi >= 3.0


def test_sqrt_clamps_negative_lower():
    r = Interval(-1.0, 4.0).sqrt()
    assert r.lo <= 0.0 and r.hi >= 2.0


def test_sqrt_wholly_negative_is_nan():
    r = Interval(-4.0, -1.0).sqrt()
    assert math.isnan(r.lo) and math.isnan(r.hi)


def test_exp_ln():
    e = Interval(0.0, 1.0).exp()
    assert e.lo <= 1.0 and e.hi >= math.e
    log_interval = Interval(1.0, math.e).ln()
    assert log_interval.lo <= 0.0 and log_interval.hi >= 1.0


def test_ln_straddling_zero():
    r = Interval(0.0, 1.0).ln()
    assert math.isinf(r.lo) and r.lo < 0 and r.hi >= 0.0


def test_ln_wholly_nonpositive_is_nan():
    r = Interval(-2.0, -1.0).ln()
    assert math.isnan(r.lo) and math.isnan(r.hi)


def test_sin_cos_full_enclosure():
    s = Interval(0.0, math.pi).sin()
    assert s.lo == -1.0 and s.hi == 1.0
    c = Interval(-0.5, 0.5).cos()
    assert c.lo == -1.0 and c.hi == 1.0


def test_comparison_and_str():
    assert Interval(1.0, 2.0) == Interval(1.0, 2.0)
    assert Interval(1.0, 2.0) != Interval(1.0, 3.0)
    assert str(Interval(1.0, 2.0)) == "[1.0, 2.0]"
    assert repr(Interval(1.0, 2.0)) == "Interval(1.0, 2.0)"


def test_hash():
    assert hash(Interval(1.0, 2.0)) == hash(Interval(1.0, 2.0))
