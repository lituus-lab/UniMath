# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/unittest
import std/math except sqrt
import UniMath

const Tol = 1e-12

proc near(a, b: Complex[float64], tol = Tol): bool =
  abs(a.re - b.re) <= tol and abs(a.im - b.im) <= tol

suite "Complex modulus and argument":
  test "abs is the Euclidean modulus":
    check abs(complex(3.0, 4.0)) == 5.0
    check abs(complex(0.0, 0.0)) == 0.0
    check abs(complex(-3.0, 0.0)) == 3.0
    check abs(complex(0.0, -4.0)) == 4.0
  test "abs scales instead of squaring, so it survives overflow":
    # sqrt(norm2(z)) is +Inf here; the scaled form is finite.
    check abs(complex(1e300, 1e300)) == 1e300 * sqrt(2.0)
    check abs(complex(3e-320, 4e-320)) > 0.0
  test "arg is the principal argument in (-pi, pi]":
    check abs(arg(complex(1.0, 0.0))) < Tol
    check abs(arg(complex(-1.0, 0.0)) - PI) < Tol
    check abs(arg(complex(0.0, 1.0)) - PI / 2) < Tol
    check abs(arg(complex(0.0, -1.0)) + PI / 2) < Tol
  test "polar and rect round-trip":
    let z = complex(1.5, -2.5)
    let (r, theta) = polar(z)
    check near(rect(r, theta), z, 1e-14)

suite "Complex square root":
  test "sqrt(-1) is the +i root":
    check near(sqrt(complex(-1.0, 0.0)), complex(0.0, 1.0))
    check near(csqrt(-1.0), complex(0.0, 1.0))
    check $csqrt(-1.0) == "0.0+1.0i"
  test "csqrt promotes only on the negative side":
    check near(csqrt(4.0), complex(2.0, 0.0))
    check near(csqrt(0.0), complex(0.0, 0.0))
    check near(csqrt(-4.0), complex(0.0, 2.0))
  test "the real sqrt keeps its domain guard":
    # csqrt is a separate name precisely so this stays a raise.
    expect(ValueError):
      discard sqrtNewtonGeneric(-1.0)
  test "sqrt squared returns the argument on both sides of the cut":
    for z in [complex(3.0, 4.0), complex(-3.0, 4.0), complex(-3.0, -4.0),
              complex(3.0, -4.0), complex(0.0, 2.0), complex(-2.0, 0.0)]:
      let r = sqrt(z)
      check near(r * r, z, 1e-13)
  test "sqrt of zero is zero":
    check sqrt(complex(0.0, 0.0)) == complex(0.0, 0.0)
  test "the result lies on the principal branch (re >= 0)":
    for z in [complex(-3.0, 4.0), complex(-3.0, -4.0), complex(-1.0, 0.0)]:
      check sqrt(z).re >= 0.0
  test "the sign of the imaginary part is carried across the cut":
    check sqrt(complex(-3.0, 4.0)).im > 0.0
    check sqrt(complex(-3.0, -4.0)).im < 0.0

suite "Complex exponential and logarithm":
  test "Euler's identity":
    check near(exp(complex(0.0, PI)), complex(-1.0, 0.0), 1e-15)
    check near(exp(complex(0.0, 0.0)), complex(1.0, 0.0))
  test "exp(a+bi) = exp(a)(cos b + i sin b)":
    let z = complex(1.5, 0.75)
    check near(exp(z), complex(exp(1.5) * cos(0.75), exp(1.5) * sin(0.75)))
  test "ln is the inverse of exp inside the principal strip":
    for z in [complex(1.0, 0.5), complex(-2.0, 1.0), complex(0.5, -0.25)]:
      check near(exp(ln(z)), z, 1e-13)
  test "ln(-1) is i*pi — the branch cut":
    check near(ln(complex(-1.0, 0.0)), complex(0.0, PI))
    check near(cln(-1.0), complex(0.0, PI))
  test "cln promotes only on the negative side":
    check near(cln(1.0), complex(0.0, 0.0))
    check near(cln(E), complex(1.0, 0.0))
  test "ln of complex zero raises":
    expect(ValueError):
      discard ln(complex(0.0, 0.0))

suite "Complex trigonometry and hyperbolics":
  test "sin(a+bi) = sin a cosh b + i cos a sinh b":
    let z = complex(1.0, 1.0)
    check near(sin(z), complex(sin(1.0) * cosh(1.0), cos(1.0) * sinh(1.0)))
    check near(cos(z), complex(cos(1.0) * cosh(1.0), -(sin(1.0) * sinh(1.0))))
  test "sin^2 + cos^2 == 1":
    for z in [complex(1.0, 1.0), complex(-0.5, 2.0), complex(0.0, 0.0)]:
      let s = sin(z)
      let c = cos(z)
      check near(s * s + c * c, complex(1.0, 0.0), 1e-12)
  test "cosh^2 - sinh^2 == 1":
    for z in [complex(1.0, 1.0), complex(-0.5, 0.75)]:
      let sh = sinh(z)
      let ch = cosh(z)
      check near(ch * ch - sh * sh, complex(1.0, 0.0), 1e-12)
  test "sin(iz) = i sinh(z)":
    let z = complex(0.75, -0.25)
    let i = imagUnit(Complex[float64])
    check near(sin(i * z), i * sinh(z), 1e-13)
  test "tan and tanh are the quotients":
    let z = complex(0.5, 0.25)
    check near(tan(z), sin(z) / cos(z))
    check near(tanh(z), sinh(z) / cosh(z))
  test "the real axis agrees with the real functions":
    check near(sin(complex(1.0, 0.0)), complex(sin(1.0), 0.0))
    check near(cos(complex(1.0, 0.0)), complex(cos(1.0), 0.0))
    check near(exp(complex(1.0, 0.0)), complex(exp(1.0), 0.0))

suite "Complex powers":
  test "the complex power agrees with the integer one":
    let z = complex(1.0, 2.0)
    for k in 1 .. 5:
      check near(pow(z, complex(float64(k), 0.0)), pow(z, k), 1e-12)
  test "i^i is real":
    let i = imagUnit(Complex[float64])
    let r = pow(i, i)
    check abs(r.im) < Tol
    check abs(r.re - exp(-PI / 2)) < Tol
  test "sqrt(z) == z^(1/2)":
    let z = complex(-3.0, 4.0)
    check near(sqrt(z), pow(z, complex(0.5, 0.0)), 1e-13)
  test "a zero base raises through ln":
    expect(ValueError):
      discard pow(complex(0.0, 0.0), complex(2.0, 0.0))

suite "Complex over BigFloat":
  test "modulus and the branch cut carry to the multi-precision backend":
    let z = complex(initBigFloat(3.0, 128), initBigFloat(4.0, 128))
    check abs(toFloat64(abs(z)) - 5.0) < 1e-12
    let r = csqrt(initBigFloat(-1.0, 128))
    check abs(toFloat64(r.re)) < 1e-12
    check abs(toFloat64(r.im) - 1.0) < 1e-12
  test "ln of a negative real lands on the cut":
    check abs(toFloat64(cln(initBigFloat(-1.0, 128)).im) - PI) < 1e-12

suite "Complex is not a RealField":
  test "the ordered-field generics reject Complex":
    # sqrtNewtonGeneric is bounded on OrderedField; Complex has no order, so
    # the instantiation must fail rather than compute a wrong root.
    check not compiles(sqrtNewtonGeneric(complex(1.0, 0.0)))
  test "abs returns the component, not a Complex":
    check abs(complex(3.0, 4.0)) is float64

suite "Complex logarithm against the unit circle":
  test "the real part keeps its own scale as |z| approaches 1":
    # Re(ln z) = ln|z| tends to zero there while |z| tends to one, so a naive
    # ln(abs(z)) loses a digit per power of ten between them: it was 4.6e-5
    # out at |z| - 1 == 1e-12, and once |z| rounds to 1 it returns a flat 0.
    #
    # z = 1 + i*2^-k has |z|^2 - 1 == 2^-2k EXACTLY, so the reference carries
    # no construction rounding of its own -- building z from cos/sin instead
    # would perturb |z| by an ulp and swamp the very quantity under test.
    for k in 10 .. 30:
      let t2 = pow(2.0, -float64(2 * k))
      let z = complex(1.0, pow(2.0, -float64(k)))
      # ln|z| = ln(1 + t2)/2, series truncated past t2^3/3 (relative t2^3/4,
      # below 1e-18 across this range).
      let want = 0.5 * (t2 - t2 * t2 / 2.0 + t2 * t2 * t2 / 3.0)
      check abs(ln(z).re - want) <= 1e-14 * abs(want)
  test "exactly on the unit circle the real part is exactly zero":
    # Only the four axis points are exactly on the circle in binary; anything
    # from cos/sin is an ulp off it and would test the rounding instead.
    for z in [complex(1.0, 0.0), complex(0.0, 1.0),
              complex(-1.0, 0.0), complex(0.0, -1.0)]:
      check ln(z).re == 0.0
  test "the imaginary part is still the argument":
    for k in [2, 8, 14]:
      let d = pow(10.0, -float64(k))
      let z = complex((1.0 + d) * cos(0.7), (1.0 + d) * sin(0.7))
      check abs(ln(z).im - 0.7) < 1e-15
  test "far from the unit circle nothing regressed":
    for m in [1e-8, 1e-3, 10.0, 1e8]:
      let z = complex(m * cos(0.4), m * sin(0.4))
      check abs(ln(z).re - ln(m)) <= 1e-15 * abs(ln(m))
