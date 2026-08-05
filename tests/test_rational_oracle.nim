# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Rational cross-check against the independent GMP oracle (mpq, auto-reduced).
## Nim `Rational[BigInt]` add/sub/mul and cmp are compared to GMP's exact
## reduced results — a different library, so a match is independent confirmation.
## Run with `nimble testOracle` (needs libgmp; not in the default gate).
import std/[unittest, random]
import UniMath
import oracles/oracle

proc rat(num, den: int): Rational[BigInt] =
  initRational(initBigInt(num), initBigInt(den))

proc decR(r: Rational[BigInt]): (string, string) =
  (toDecimal(r.num), toDecimal(r.den))

suite "Rational vs GMP — arithmetic":
  test "add/sub/mul match the exact reduced reference":
    let cases: seq[(string, Rational[BigInt], Rational[BigInt])] = @[
      ("radd", rat(1, 2), rat(1, 3)),
      ("rsub", rat(1, 2), rat(1, 3)),
      ("rmul", rat(2, 3), rat(4, 5)),
      ("radd", rat(-3, 4), rat(3, 4)),
      ("rmul", rat(-2, 7), rat(7, 3)),
    ]
    for (op, a, b) in cases:
      let r = case op
        of "radd": a + b
        of "rsub": a - b
        of "rmul": a * b
        else: rat(0, 1)
      let (na, da) = decR(a)
      let (nb, db) = decR(b)
      let (gn, gd) = gmpRationalOp(op, na, da, nb, db)
      check toDecimal(r.num) == gn
      check toDecimal(r.den) == gd

  test "cmp matches mpq":
    let pairs: seq[(Rational[BigInt], Rational[BigInt])] = @[
      (rat(1, 2), rat(1, 3)), (rat(1, 3), rat(1, 2)), (rat(2, 4), rat(1, 2)),
      (rat(-1, 2), rat(1, 2)), (rat(3, 1), rat(6, 2)),
    ]
    for (a, b) in pairs:
      let (na, da) = decR(a)
      let (nb, db) = decR(b)
      check cmp(a, b) == gmpRationalCmp(na, da, nb, db)

suite "Rational vs GMP — randomized":
  test "add/mul of random rationals":
    randomize(20260722)
    for _ in 0 ..< 200:
      let an = rand(-100000 .. 100000)
      let ad = rand(1 .. 100000)
      let bn = rand(-100000 .. 100000)
      let bd = rand(1 .. 100000)
      let a = rat(an, ad)
      let b = rat(bn, bd)
      let (na, da) = decR(a)
      let (nb, db) = decR(b)
      block addCheck:
        let (gn, gd) = gmpRationalOp("radd", na, da, nb, db)
        let r = a + b
        check toDecimal(r.num) == gn
        check toDecimal(r.den) == gd
      block mulCheck:
        let (gn, gd) = gmpRationalOp("rmul", na, da, nb, db)
        let r = a * b
        check toDecimal(r.num) == gn
        check toDecimal(r.den) == gd
      check cmp(a, b) == gmpRationalCmp(na, da, nb, db)
