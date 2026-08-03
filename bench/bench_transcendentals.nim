# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Perf + precision-parity bench for the transcendentals across the three
## backends: BigFloat (float_math), Fixed Q32.32 (math_router), and
## Rational[BigInt] (rational_math). The parity section compares BigFloat at
## 256-bit against the float64 `math` oracle and reports the absolute error,
## demonstrating that the multi-precision result tracks the IEEE-64 reference
## to within the double's own precision. Built by `nimble bench`; not in the
## default gate.
import std/[strutils, times, math]
import UniMath
import UniMath/math_router
import UniMath/rational_math

var sink: uint64 = 0

proc keep(p: int) {.inline: false.} =
  sink = sink xor cast[uint64](p)

template bench(name: string, iters: int, body: untyped) =
  let start = cpuTime()
  for _ in 1 .. iters:
    body
  let elapsed = cpuTime() - start
  let ns = (elapsed * 1_000_000_000) / float64(iters)
  echo alignLeft(name, 34), " | ", formatFloat(ns, ffDecimal, 3), " ns/op | ",
       formatFloat(float64(iters) / elapsed, ffDecimal, 0), " ops/sec"

proc parity(name: string, got, want: float64) =
  echo alignLeft(name, 30), " | got ", formatFloat(got, ffDecimal, 15),
       " | oracle ", formatFloat(want, ffDecimal, 15),
       " | |err| = ", formatFloat(abs(got - want), ffScientific, 2)

proc runPerf() =
  echo "UniMath transcendental benchmarks (release)"
  echo repeat('-', 70)
  let one = initBigFloat(1.0)
  let two = initBigFloat(2.0)
  bench("BigFloat sin(1)", 20000):
    var z = sin(one)
    keep(cast[int](unsafeAddr(z)))
  bench("BigFloat exp(1)", 20000):
    var z = exp(one)
    keep(cast[int](unsafeAddr(z)))
  bench("BigFloat ln(2)", 20000):
    var z = ln(two)
    keep(cast[int](unsafeAddr(z)))
  bench("BigFloat sqrt(2)", 40000):
    var z = sqrt(two)
    keep(cast[int](unsafeAddr(z)))
  bench("BigFloat arctan(1)", 20000):
    var z = arctan(one)
    keep(cast[int](unsafeAddr(z)))

  let f1 = toFixed[int64, 32](1.0)
  let f2 = toFixed[int64, 32](2.0)
  bench("Fixed sin(1) (router)", 100000):
    var z = math_router.sin(f1)
    keep(cast[int](unsafeAddr(z)))
  bench("Fixed atan(1) (router)", 100000):
    var z = math_router.atan(f1)
    keep(cast[int](unsafeAddr(z)))
  bench("Fixed sqrt(2) (router)", 100000):
    var z = math_router.sqrt(f2)
    keep(cast[int](unsafeAddr(z)))
  bench("Fixed exp(1) (router)", 50000):
    var z = math_router.exp(f1)
    keep(cast[int](unsafeAddr(z)))

  let rHalf = initRational(initBigInt(1), initBigInt(2))
  let rTwo = initRational(initBigInt(2), initBigInt(1))
  bench("Rational sin(1/2)", 20000):
    var z = rational_math.sin(rHalf)
    keep(cast[int](unsafeAddr(z)))
  bench("Rational sqrt(2)", 20000):
    var z = rational_math.sqrt(rTwo)
    keep(cast[int](unsafeAddr(z)))

  echo "sink = ", sink # keep every result live across the suite

proc runParity() =
  echo ""
  echo "Precision parity: BigFloat (256-bit) vs float64 math oracle"
  echo repeat('-', 70)
  let one = initBigFloat(1.0)
  let two = initBigFloat(2.0)
  let half = initBigFloat(0.5)
  parity("sin(1)", toFloat64(sin(one)), math.sin(1.0))
  parity("cos(1)", toFloat64(cos(one)), math.cos(1.0))
  parity("exp(1)", toFloat64(exp(one)), math.exp(1.0))
  parity("ln(2)", toFloat64(ln(two)), math.ln(2.0))
  parity("sqrt(2)", toFloat64(sqrt(two)), math.sqrt(2.0))
  parity("arctan(1)", toFloat64(arctan(one)), math.arctan(1.0))
  parity("arctan(0.5)", toFloat64(arctan(half)), math.arctan(0.5))

when isMainModule:
  runPerf()
  runParity()
