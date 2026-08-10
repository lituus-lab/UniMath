# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import UniMath

suite "Complex construction":
  test "cartesian and real embedding":
    let z = complex(1.0, 2.0)
    check z.re == 1.0 and z.im == 2.0
    let r = complex(3.0)
    check r.re == 3.0 and r.im == 0.0
    check r.isReal
  test "imaginary unit":
    let i = imagUnit(Complex[float64])
    check i.re == 0.0 and i.im == 1.0
    check i.isImaginary
  test "fromInt typedesc is v + 0i":
    check fromInt(Complex[float64], 7) == complex(7.0, 0.0)
    check fromInt(Complex[float64], 0).isZero
  test "zero uses fromInt, not default — Rational stays 0/1":
    # `default(Rational)` is 0/0 and violates the den > 0 invariant; the
    # constructor must go through fromInt.
    let z = complex(initRational(1, 2))
    check z.im.num == 0 and z.im.den == 1
  test "conj flips the imaginary part":
    check conj(complex(1.0, 2.0)) == complex(1.0, -2.0)
    check conj(complex(1.0, 0.0)) == complex(1.0, 0.0)
  test "norm2 is the exact squared modulus":
    check complex(3.0, 4.0).norm2 == 25.0
    check complex(initRational(1, 2), initRational(3, 4)).norm2 ==
      initRational(13, 16)

suite "Complex formatting":
  test "$ is the rectangular form with a signed imaginary part":
    check $complex(0.0, 1.0) == "0.0+1.0i"
    check $complex(1.0, -2.0) == "1.0-2.0i"
  test "$ delegates to the component's own $":
    check $complex(initRational(1, 2), initRational(-3, 4)) == "1/2-3/4i"

suite "Complex arithmetic":
  test "add sub":
    let a = complex(1.0, 2.0)
    let b = complex(3.0, -1.0)
    check a + b == complex(4.0, 1.0)
    check a - b == complex(-2.0, 3.0)
  test "mul":
    check complex(1.0, 2.0) * complex(3.0, -1.0) == complex(5.0, 5.0)
    # i^2 == -1 is the defining identity.
    let i = imagUnit(Complex[float64])
    check i * i == complex(-1.0, 0.0)
  test "div is the inverse of mul":
    # Float roundoff makes the round trip faithful, not exact; the exact
    # identity is asserted on the Rational backend below.
    let a = complex(1.0, 2.0)
    let b = complex(3.0, -1.0)
    let r = (a * b) / b
    check abs(r.re - a.re) < 1e-15 and abs(r.im - a.im) < 1e-15
  test "unary negation":
    check -complex(1.0, -2.0) == complex(-1.0, 2.0)
  test "inv is the multiplicative inverse":
    let a = complex(3.0, 4.0)
    check a * inv(a) == complex(1.0, 0.0)
  test "division by zero raises":
    expect(Defect):
      discard complex(1.0, 1.0) / complex(0.0, 0.0)
    expect(Defect):
      discard inv(complex(0.0, 0.0))
  test "Smith's algorithm survives a squared-magnitude overflow":
    # norm2 of either operand is +Inf; the textbook formula yields NaN.
    check complex(1e300, 1e300) / complex(1e300, 1e300) == complex(1.0, 0.0)
    check complex(1e-300, 1e-300) / complex(1e-300, 1e-300) ==
      complex(1.0, 0.0)
  test "mixed complex-scalar forms":
    let a = complex(1.0, 2.0)
    check a * 3.0 == complex(3.0, 6.0)
    check 3.0 * a == complex(3.0, 6.0)
    check a / 2.0 == complex(0.5, 1.0)
    check a + 1.0 == complex(2.0, 2.0)
    check 1.0 + a == complex(2.0, 2.0)
    check a - 1.0 == complex(0.0, 2.0)
    check 1.0 - a == complex(0.0, -2.0)

suite "Complex equality":
  test "componentwise":
    check complex(1.0, 2.0) == complex(1.0, 2.0)
    check complex(1.0, 2.0) != complex(1.0, 2.5)
  test "a complex equals a scalar only when purely real":
    check complex(2.0, 0.0) == 2.0
    check 2.0 == complex(2.0, 0.0)
    check not (complex(2.0, 1.0) == 2.0)
  test "no order is defined on Complex":
    # Guards the concept boundary: an accidental `<` would let Complex satisfy
    # OrderedField/RealField and silently feed generic Euclidean-norm code.
    check not compiles(complex(1.0, 0.0) < complex(2.0, 0.0))
    check not compiles(cmp(complex(1.0, 0.0), complex(2.0, 0.0)))

suite "Complex over the exact backends":
  test "Rational stays exact through the ring operations":
    let z = complex(initRational(1, 2), initRational(3, 4))
    check z * conj(z) == complex(initRational(13, 16), initRational(0, 1))
    check z / z == complex(initRational(1, 1), initRational(0, 1))
    check pow(z, 2) == complex(initRational(-5, 16), initRational(3, 4))
  test "Rational over BigInt is unbounded":
    let big = initBigInt(1_000_000_000)
    let z = complex(initRational(big, initBigInt(1)),
                    initRational(big, initBigInt(1)))
    # (a + ai)^2 = 2a^2 i — exact, well past int64 for a = 1e9.
    let sq = pow(z, 2)
    check sq.re == initRational(initBigInt(0), initBigInt(1))
    check sq.im == initRational(big * big * initBigInt(2), initBigInt(1))
  test "Fixed carries the ring operations":
    let z = complex(toFixed[int64, 32](3), toFixed[int64, 32](4))
    check z * conj(z) == complex(toFixed[int64, 32](25),
                                 toFixed[int64, 32](0))

suite "Complex satisfies the Field concept":
  test "the generic Field series accept Complex unchanged":
    # expTaylor is bounded on Field: exp(i) must be cos 1 + i sin 1.
    let e = expTaylor(imagUnit(Complex[float64]), 20)
    check abs(e.re - 0.5403023058681398) < 1e-12
    check abs(e.im - 0.8414709848078965) < 1e-12
  test "integer coefficients reach the series through fromInt":
    check sinTaylor(complex(1.0, 0.0), 12).re - 0.8414709848078965 < 1e-12

suite "Complex integer power":
  test "binary exponentiation matches repeated multiplication":
    let z = complex(1.0, 2.0)
    var acc = fromInt(Complex[float64], 1)
    for k in 0 .. 6:
      check pow(z, k) == acc
      acc = acc * z
  test "pow(z, 0) is one for every z, zero included":
    check pow(complex(0.0, 0.0), 0) == complex(1.0, 0.0)
  test "a negative exponent inverts":
    let z = complex(0.0, 1.0)
    check pow(z, -1) == complex(0.0, -1.0)
    check pow(z, -2) == complex(-1.0, 0.0)
  test "a negative exponent of zero raises":
    expect(Defect):
      discard pow(complex(0.0, 0.0), -1)
