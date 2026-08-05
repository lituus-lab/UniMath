# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
#
# Smoke test for the oracle bridge: proves the three oracles (GMP, MPFR, the
# decimal EFT) build and answer over the text pipe protocol. Not in the
# default gate — run with `nimble testOracle` (needs libmpfr/libgmp). The
# per-package oracle suites (BigInt/Fixed/Rational/BigFloat transcendentals)
# land in their own slices and reuse this bridge.
import std/[math, unittest]
import oracles/oracle

suite "GMP oracle (exact integer/rational/fixed)":
  test "add/sub/mul of unbounded integers":
    check gmpBinop("add", "123456789", "987654321") == "1111111110"
    check gmpBinop("sub", "0", "1") == "-1"
    check gmpBinop("mul", "1000000000000", "1000000000000") == "1000000000000000000000000"

  test "signed and unsigned divmod":
    let (q, r) = gmpDivMod("100", "7")
    check (q, r) == ("14", "2")
    let (uq, ur) = gmpUDivMod("100", "7")
    check (uq, ur) == ("14", "2")

  test "reconstruction is convention-agnostic":
    check gmpReconstruct("100", "7", "14", "2")
    check gmpReconstruct("100", "7", "15", "-5")

  test "signed comparison":
    check gmpCmp("-5", "5") == -1
    check gmpCmp("5", "5") == 0
    check gmpCmp("5", "-5") == 1

  test "rational comparison and reduction":
    check gmpRationalCmp("1", "2", "1", "3") == 1
    let (n, d) = gmpRationalOp("radd", "1", "6", "1", "3")
    check (n, d) == ("1", "2")

  test "fixed mul/div via the BigInt intermediate":
    check gmpFixedMul(2, "7", "3") == "5" # (7*3) >> 2 = 5
    check gmpFixedDiv(2, "5", "4") == "5" # (5 << 2) / 4 = 5

suite "MPFR oracle (transcendentals)":
  const RefPrec = 2048

  test "sqrt(2) is correctly rounded to binary64":
    check mpfrRef("sqrt", RefPrec, 2.0) == sqrt(2.0)

  test "exp/ln round-trip at binary64":
    let e = mpfrRef("exp", RefPrec, 1.0)
    # Not `== math.exp(1.0)`: IEEE 754 mandates correct rounding for sqrt but
    # not for exp, and the libm result differs by up to 1 ulp between glibc,
    # Apple's libm and the MSVC CRT -- all three run in CI. The literal is the
    # correctly-rounded binary64 value of e; the round-trip below is the real
    # assertion.
    check e == 2.718281828459045
    check mpfrRef("ln", RefPrec, e) == 1.0

  test "candidate error is <= 0.5 ulp when correctly rounded":
    let cand = sqrt(2.0)
    let (_, _, ulp) = mpfrErr("sqrt", RefPrec, cand, 2.0)
    check ulp <= 0.5

suite "decimal EFT oracle (twoSum/twoProduct identity)":
  test "exact cases carry no error":
    let s = eftOracle([("sum", 1.0, 1.0), ("prod", 2.0, 3.0)])
    check s == @[(2.0, 0.0), (6.0, 0.0)]

  test "0.1 + 0.2 splits into head and exact tail":
    let r = eftOracle([("sum", 0.1, 0.2)])
    # the famous correctly-rounded sum, and a non-zero exact residual whose
    # magnitude is below half an ulp of the result (the EFT guarantee).
    check r[0][0] == 0.30000000000000004
    check r[0][1] != 0.0
    check abs(r[0][1]) < 1e-16

  test "float32 mode rounds to binary32":
    let r = eftOracle([("sum", 1.0, 1.0)], asF32 = true)
    check r[0] == (2.0, 0.0)
