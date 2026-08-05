#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Exact EFT oracle for UniMath tests.

Reads whitespace-separated queries from stdin, one per line:
    <op> <a> <b> [<prec>]
where <op> is one of `sum`, `diff`, `prod`; <a>, <b> are Python float
literals (Nim's shortest round-trip `$` repr round-trips through float());
and the optional <prec> is `f64` (default) or `f32`, selecting the target
precision to round to.

For each query, computes the exact real result with decimal.Decimal and
prints the correctly-rounded result `s` and the exact rounding error `e`
(both as repr strings of the value widened back to float64, so they
round-trip through Nim's `parseFloat`), space-separated:
    <s> <e>

Mathematics: for an EFT of op(a, b) returning (s, e), the real value
a op b equals s + e exactly, with s = round_to_nearest(a op b) and
e = (a op b) - s, which is exactly representable under IEEE-754
roundTiesToEven with FLT_EVAL_METHOD == 0 (no x87 double rounding).

float32 mode rounds `s` and `e` to binary32 via `struct` (C cast semantics,
round-to-nearest-even). float32 -> float64 widening is exact, so the
emitted float64 reprs equal the float32 values bit-for-bit.

Overflow (exact result beyond the target format) yields s = +-inf and
e = nan; callers must exclude such cases (the EFT identity does not hold).

Used by oracles/oracle.nim to verify twoSum / twoDiff / twoProduct
in both float64 and float32.
"""
import struct
import sys
from decimal import Decimal, getcontext

# Precision must hold the *exact decimal expansion* of the operands and of the
# real result, not merely the ~17 round-trip digits of a double. The exact
# decimal value of a float64 spans up to 767 digits (smallest subnormal
# 2^-1074 ~ 5e-324 has 324; largest normal ~1e308 has 309), and a product of
# two doubles needs up to ~617 significant digits. With prec=80 the addition
# `da + db` is rounded to 80 significant digits *before* the error is computed,
# so for operands with >80 digits (e.g. 1e100) the low-order error is discarded
# and `exact - Decimal(s)` returns garbage. 800 gives comfortable margin for
# every finite, non-overflowing float64 EFT case in the test set.
getcontext().prec = 800


def _to_f32(x: float) -> float:
    """Round a real value (as float64) to binary32, returned as float64."""
    return struct.unpack("f", struct.pack("f", x))[0]


def exact_parts(op: str, a: float, b: float, prec: str) -> tuple[float, float]:
    da, db = Decimal(a), Decimal(b)
    if op == "sum":
        exact = da + db
    elif op == "diff":
        exact = da - db
    elif op == "prod":
        exact = da * db
    else:
        raise ValueError(f"unknown op: {op}")

    if prec == "f32":
        # Safe (no double rounding): the exact real result of two f32
        # operands fits in float64 (sum/diff <= 25 sig bits, product <= 48),
        # so float(exact) is exact and _to_f32 is the only rounding applied.
        s = _to_f32(float(exact))
        e = _to_f32(float(exact - Decimal(s)))
    else:
        s = float(exact)                       # correctly rounded to float64
        e = float(exact - Decimal(s))          # exact rounding error (representable)
    return s, e


def main() -> None:
    out = []
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        parts = line.split()
        op, a_s, b_s = parts[0], parts[1], parts[2]
        prec = parts[3] if len(parts) > 3 else "f64"
        if prec not in ("f32", "f64"):
            raise ValueError(f"unknown prec: {prec}")
        a, b = float(a_s), float(b_s)
        s, e = exact_parts(op, a, b, prec)
        out.append(f"{s!r} {e!r}")
    sys.stdout.write("\n".join(out) + ("\n" if out else ""))


if __name__ == "__main__":
    main()