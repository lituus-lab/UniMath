# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import gc

import pytest

import unimath
from unimath import BigInt


def test_from_int_and_str_round_trip():
    assert str(BigInt(0)) == "0"
    assert str(BigInt(-123456789)) == "-123456789"
    assert str(BigInt(10**21)) == "1000000000000000000000"


def test_arithmetic():
    a = BigInt(1_000_000_000_000)
    b = BigInt(1)
    assert str(a + b) == "1000000000001"
    assert str(a - b) == "999999999999"
    assert str(a * b) == "1000000000000"
    assert str(BigInt(-7) + BigInt(2)) == "-5"
    assert str(BigInt(-7) - BigInt(2)) == "-9"
    assert str(BigInt(-3) * BigInt(-4)) == "12"


def test_divmod_truncates_toward_zero():
    assert str(BigInt(100) // BigInt(7)) == "14"
    assert str(BigInt(100) % BigInt(7)) == "2"
    assert str(BigInt(-7) // BigInt(2)) == "-3"
    assert str(BigInt(-7) % BigInt(2)) == "-1"


def test_div_by_zero_raises():
    with pytest.raises(ZeroDivisionError):
        BigInt(1) // BigInt(0)
    with pytest.raises(ZeroDivisionError):
        BigInt(1) % BigInt(0)


def test_neg_abs():
    assert str(-BigInt(7)) == "-7"
    assert str(-BigInt(-7)) == "7"
    assert str(abs(BigInt(-7))) == "7"
    assert str(abs(BigInt(7))) == "7"


def test_comparison():
    assert BigInt(-5) < BigInt(5)
    assert BigInt(5) == BigInt(5)
    assert BigInt(5) > BigInt(-5)
    assert BigInt(3) <= BigInt(3)
    assert BigInt(4) >= BigInt(3)
    assert BigInt(2) != BigInt(3)


def test_to_i64_clamps():
    v, ok = BigInt(-42).to_i64()
    assert (v, ok) == (-42, True)
    v, ok = BigInt(10**21).to_i64()
    assert ok is False
    assert v == 2**63 - 1  # clamped to int64 max


def test_handles_survive_gc():
    # a BigInt whose handle is only held by Python must survive a collection
    big = BigInt(10**30) * BigInt(10**30)
    gc.collect()
    assert str(big) == "1" + "0" * 60  # 10**60


def test_coerce_int_operand():
    assert str(BigInt(5) + 3) == "8"
    assert str(BigInt(5) * 4) == "20"


def test_hash_matches_equal_int():
    # a == b => hash(a) == hash(b): BigInt(7) == 7 (int coerced via _coerce), so
    # they must hash alike. The old hash(str(self)) hashed the string "7" and
    # broke the invariant (set/dict dedup across int and BigInt).
    assert hash(BigInt(7)) == hash(7)
    assert hash(BigInt(-3)) == hash(-3)
    assert hash(BigInt(10**21)) == hash(10**21)
    # cross-type dedup in a set relies on the hash invariant
    assert len({BigInt(1), 1, BigInt(1)}) == 1


def test_reflected_operators():
    # int OP BigInt: int.__add__ etc. return NotImplemented, so Python calls the
    # BigInt reflected ops. sub/floordiv/mod compute `other OP self`.
    assert (1 + BigInt(2)) == BigInt(3)
    assert (5 - BigInt(2)) == BigInt(3)
    assert (3 * BigInt(4)) == BigInt(12)
    assert (10 // BigInt(3)) == BigInt(3)
    assert (10 % BigInt(3)) == BigInt(1)


def test_reflected_div_by_zero():
    with pytest.raises(ZeroDivisionError):
        10 // BigInt(0)
    with pytest.raises(ZeroDivisionError):
        10 % BigInt(0)


def test_to_u64_clamps():
    v, ok = BigInt(42).to_u64()
    assert (v, ok) == (42, True)
    v, ok = BigInt(-1).to_u64()
    assert ok is False
    assert v == 0
    v, ok = BigInt(10**21).to_u64()
    assert ok is False
    assert v == 2**64 - 1  # clamped to uint64 max


def test_shl_shr():
    assert str(BigInt(3) << 4) == "48"
    assert str(BigInt(48) >> 4) == "3"
    # arithmetic shift right floors, not truncates toward zero
    assert str(BigInt(-7) >> 1) == "-4"
    assert str(BigInt(-1) >> 100) == "-1"  # -1 stays -1 (all-ones magnitude)


def test_shl_shr_negative_count_raises():
    with pytest.raises(ValueError):
        BigInt(3) << -1
    with pytest.raises(ValueError):
        BigInt(3) >> -1
