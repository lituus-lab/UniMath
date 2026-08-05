# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## EFT re-export smoke tests. UniAccurate carries its own decimal-oracle tests
## for the error-free-transform identities; here we only confirm the symbols are
## re-exported through `UniMath` and behave on exact / known-error cases.
import std/unittest
import UniMath

suite "EFT primitives":
  test "twoSum exact":
    let (s, e) = twoSum(1.0, 2.0)
    check s == 3.0 and e == 0.0
  test "twoSum rounded sum":
    let (s, e) = twoSum(1.0, 1.0 / 3.0)
    check s == 1.0 + 1.0 / 3.0
    check e != 0.0
  test "twoDiff exact":
    let (s, e) = twoDiff(5.0, 3.0)
    check s == 2.0 and e == 0.0
  test "twoProduct exact":
    let (p, e) = twoProduct(2.0, 3.0)
    check p == 6.0 and e == 0.0
  test "twoProduct carries error":
    let (p, e) = twoProduct(0.1, 0.2)
    check p == 0.1 * 0.2
    check e != 0.0
  test "twoSquare exact":
    let (p, e) = twoSquare(3.0)
    check p == 9.0 and e == 0.0
  test "twoSquare carries error":
    let (p, e) = twoSquare(0.1)
    check p == 0.1 * 0.1
    check e != 0.0
  test "split reconstructs":
    let (hi, lo) = split(1.0)
    check hi + lo == 1.0
  test "ulp at 1.0 is 2^-52":
    check ulp(1.0) == 1.0 / float(1 shl 52)

suite "Shewchuk expansions":
  test "growExpansion":
    let e = growExpansion([1.0, 2.0], 3.0)
    check estimate(e) == 6.0
  test "fastExpansionSumZeroElim":
    let e = fastExpansionSumZeroElim([1.0, 2.0], [3.0, 4.0])
    check estimate(e) == 10.0
  test "scaleExpansionZeroElim":
    let e = scaleExpansionZeroElim([1.0, 2.0], 3.0)
    check estimate(e) == 9.0
  test "zeroElim drops zeros":
    let e = zeroElim([1.0, 0.0, 2.0])
    check estimate(e) == 3.0
    for c in e:
      check c != 0.0
