# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import pytest

from unimath import Fixed


def test_from_int_and_to_int():
    f = Fixed(3, frac_bits=16)
    assert f.raw() == 3 << 16
    assert f.to_int() == 3


def test_from_float_scales():
    f = Fixed(3.75, frac_bits=16)
    assert f.raw() == int(3.75 * (1 << 16))
    assert f.to_int() == 3


def test_arithmetic():
    a = Fixed(3, frac_bits=16)
    b = Fixed(2, frac_bits=16)
    assert (a + b).to_int() == 5
    assert (a - b).to_int() == 1
    # 2 * 3 = 6 real -> 6 << 16
    assert (Fixed(2, frac_bits=16) * Fixed(3, frac_bits=16)).raw() == 6 << 16
    # 7 / 2 = 3.5 real -> 3.5 << 16 = 229376; to_int truncates to 3
    q = Fixed(7, frac_bits=16) // Fixed(2, frac_bits=16)
    assert q.raw() == 229376
    assert q.to_int() == 3


def test_div_by_zero_is_zero():
    # The C ABI never raises; division by zero returns 0.
    assert (Fixed(7, frac_bits=16) // Fixed(0, frac_bits=16)).raw() == 0


def test_clamping():
    # Shifting int64 max left by 16 overflows; the ABI clamps to int64 max.
    assert Fixed(2**63 - 1, frac_bits=16).raw() == 2**63 - 1


def test_comparison():
    a = Fixed(3, frac_bits=16)
    b = Fixed(5, frac_bits=16)
    assert a < b
    assert b > a
    assert a == Fixed(3, frac_bits=16)
    assert a != b
    assert a <= a
    assert b >= a


def test_frac_bits_mismatch_raises():
    with pytest.raises(ValueError):
        Fixed(3, frac_bits=16) + Fixed(3, frac_bits=32)


def test_value_as_float():
    assert Fixed(3, frac_bits=16).value() == 3.0
    assert Fixed(3.5, frac_bits=16).value() == 3.5


def test_hash_matches_value():
    # Fixed(2, 16) == 2 == 2.0 (int/float coerced via _coerce_fixed), so the
    # hash must match hash(2) == hash(2.0); the old hash((raw, frac)) broke the
    # invariant (no int/float shares that tuple hash).
    assert hash(Fixed(2, frac_bits=16)) == hash(2)
    assert hash(Fixed(2, frac_bits=16)) == hash(2.0)
    assert len({Fixed(1, frac_bits=16), 1, Fixed(1, frac_bits=16)}) == 1


def test_reflected_operators():
    # int OP Fixed: int.__add__ etc. return NotImplemented, so Python calls the
    # Fixed reflected ops. sub/floordiv compute `other OP self` at self's frac.
    assert (1 + Fixed(2, frac_bits=16)) == Fixed(3, frac_bits=16)
    assert (5 - Fixed(2, frac_bits=16)) == Fixed(3, frac_bits=16)
    assert (3 * Fixed(2, frac_bits=16)) == Fixed(6, frac_bits=16)
    assert (10 // Fixed(2, frac_bits=16)) == Fixed(5, frac_bits=16)
