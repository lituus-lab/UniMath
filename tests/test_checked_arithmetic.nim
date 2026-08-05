# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed-width overflow detection under `-d:checkedArithmetic`, which the
## default suites do not compile in. The signed condition is not the unsigned
## carry: `-1 + 1` carries out of the top limb with an in-range result, and
## `high + 1` wraps without carrying. Below a limb there is no carry to read at
## all, so the bits `narrow` discards are the signal.
import std/unittest
import UniMath

suite "checked arithmetic — FixedInt":
  test "in-range sum that carries out does not raise":
    check (initFixedInt[64](-1) + initFixedInt[64](1)) == initFixedInt[64](0)
  test "signed overflow at the nominal maximum raises":
    expect(OverflowDefect):
      discard initFixedInt[64](high(int64)) + initFixedInt[64](1)
  test "signed underflow at the nominal minimum raises":
    expect(OverflowDefect):
      discard initFixedInt[64](low(int64)) - initFixedInt[64](1)
  test "sub-limb signed overflow raises":
    expect(OverflowDefect):
      discard initFixedInt[8](127) + initFixedInt[8](1)
  test "sub-limb signed sum in range does not raise":
    check (initFixedInt[8](120) + initFixedInt[8](7)) == initFixedInt[8](127)

suite "checked arithmetic — FixedUInt":
  test "unsigned overflow at a full limb raises":
    expect(OverflowDefect):
      discard initFixedUInt[64](high(uint64)) + initFixedUInt[64](1'u64)
  test "sub-limb unsigned overflow raises without a limb carry":
    expect(OverflowDefect):
      discard initFixedUInt[8](255'u64) + initFixedUInt[8](1'u64)
  test "sub-limb unsigned sum in range does not raise":
    check (initFixedUInt[8](200'u64) + initFixedUInt[8](55'u64)) ==
      initFixedUInt[8](255'u64)
  test "unsigned underflow raises":
    expect(OverflowDefect):
      discard initFixedUInt[8](0'u64) - initFixedUInt[8](1'u64)
