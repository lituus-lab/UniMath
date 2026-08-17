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
var mdPerf: seq[tuple[name: string, ns, ops: float64]] = @[]
var mdParity: seq[tuple[name: string, got, want, err: float64]] = @[]

proc keep(p: uint64) {.inline: false.} =
  sink = sink xor p

template keepVal(v: untyped) =
  ## Reads the first machine word OF the result, not its address. `unsafeAddr`
  ## alone only forces the variable to be materialised on the stack -- the
  ## address is the same every iteration, so the sink never depends on what was
  ## computed. Every benchmarked type here is at least one word wide; the
  ## assert makes a future narrower one fail loudly instead of over-reading.
  static: doAssert sizeof(v) >= 8
  keep(cast[ptr uint64](unsafeAddr(v))[])

template bench(name: string, iters: int, body: untyped) =
  let start = cpuTime()
  for _ in 1 .. iters:
    body
  let elapsed = cpuTime() - start
  let ns = (elapsed * 1_000_000_000) / float64(iters)
  let ops = float64(iters) / elapsed
  mdPerf.add((name, ns, ops))
  echo alignLeft(name, 34), " | ", formatFloat(ns, ffDecimal, 3), " ns/op | ",
       formatFloat(ops, ffDecimal, 0), " ops/sec"

proc parity(name: string, got, want: float64) =
  mdParity.add((name, got, want, abs(got - want)))
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
    keepVal(z)
  bench("BigFloat exp(1)", 20000):
    var z = exp(one)
    keepVal(z)
  bench("BigFloat ln(2)", 20000):
    var z = ln(two)
    keepVal(z)
  bench("BigFloat sqrt(2)", 40000):
    var z = sqrt(two)
    keepVal(z)
  bench("BigFloat arctan(1)", 20000):
    var z = arctan(one)
    keepVal(z)

  let f1 = toFixed[int64, 32](1.0)
  let f2 = toFixed[int64, 32](2.0)
  bench("Fixed sin(1) (router)", 100000):
    var z = math_router.sin(f1)
    keepVal(z)
  bench("Fixed atan(1) (router)", 100000):
    var z = math_router.atan(f1)
    keepVal(z)
  bench("Fixed sqrt(2) (router)", 100000):
    var z = math_router.sqrt(f2)
    keepVal(z)
  bench("Fixed exp(1) (router)", 50000):
    var z = math_router.exp(f1)
    keepVal(z)

  let rHalf = initRational(initBigInt(1), initBigInt(2))
  let rTwo = initRational(initBigInt(2), initBigInt(1))
  bench("Rational sin(1/2)", 20000):
    var z = rational_math.sin(rHalf)
    keepVal(z)
  bench("Rational sqrt(2)", 20000):
    var z = rational_math.sqrt(rTwo)
    keepVal(z)

  # Complex over three backends. `Complex[float64]` is the cheap reference;
  # `Complex[BigFloat]` shows what multi precision costs per component; the
  # Rational rows are the exact ring operations, which never leave the field
  # and so carry no truncation at all.
  # Operands rotate through an array rather than being two `let` bindings.
  # `keepVal` forces the RESULT to be used, which is not the same as forcing the
  # WORK to happen: with a loop-invariant operand the compiler computes it once
  # and the loop measures only the sink. An opaque call hides that, so this read
  # as ~1.3 ns for as long as `*` was a real call -- and collapsed to 0.007 ns,
  # 151 Gop/s, the moment it was marked {.inline.}. The indexed load costs a
  # fraction of a ns and is what a caller does anyway.
  const CN = 256
  var cfs: array[CN, Complex[float64]]
  var cgs: array[CN, Complex[float64]]
  for i in 0 ..< CN:
    cfs[i] = complex(3.0 + float64(i) * 0.01, 4.0 + float64(i) * 0.02)
    cgs[i] = complex(1.0 + float64(i) * 0.03, -2.0 - float64(i) * 0.01)
  var ci = 0
  template rot(): int =
    ci = (ci + 1) and (CN - 1)
    ci
  bench("Complex[float64] mul", 2000000):
    var z = cfs[rot()] * cgs[ci]
    keepVal(z)
  bench("Complex[float64] div", 1000000):
    var z = cfs[rot()] / cgs[ci]
    keepVal(z)
  bench("Complex[float64] abs", 2000000):
    var z = abs(cfs[rot()])
    keepVal(z)
  bench("Complex[float64] sqrt", 1000000):
    var z = sqrt(cfs[rot()])
    keepVal(z)
  bench("Complex[float64] exp", 500000):
    var z = exp(cgs[rot()])
    keepVal(z)
  bench("Complex[float64] ln", 500000):
    var z = ln(cfs[rot()])
    keepVal(z)

  let cbf = complex(initBigFloat(3.0), initBigFloat(4.0))
  let cbg = complex(initBigFloat(1.0), initBigFloat(-2.0))
  bench("Complex[BigFloat] mul", 20000):
    var z = cbf * cbg
    keepVal(z)
  bench("Complex[BigFloat] abs", 10000):
    var z = abs(cbf)
    keepVal(z)
  bench("Complex[BigFloat] sqrt", 5000):
    var z = sqrt(cbf)
    keepVal(z)
  bench("Complex[BigFloat] exp", 5000):
    var z = exp(cbg)
    keepVal(z)

  let crf = complex(initRational(initBigInt(1), initBigInt(2)),
                    initRational(initBigInt(3), initBigInt(4)))
  bench("Complex[Rational] mul (exact)", 20000):
    var z = crf * crf
    keepVal(z)
  bench("Complex[Rational] pow 8 (exact)", 5000):
    var z = pow(crf, 8)
    keepVal(z)

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
  # Complex, component by component: the multi-precision result against the
  # float64 one computed by the same closed forms.
  let cb = complex(initBigFloat(-3.0), initBigFloat(4.0))
  let cd = complex(-3.0, 4.0)
  let cbSqrt = sqrt(cb)
  let cdSqrt = sqrt(cd)
  parity("complex sqrt(-3+4i) re", toFloat64(cbSqrt.re), cdSqrt.re)
  parity("complex sqrt(-3+4i) im", toFloat64(cbSqrt.im), cdSqrt.im)
  let cbLn = ln(cb)
  let cdLn = ln(cd)
  parity("complex ln(-3+4i) re", toFloat64(cbLn.re), cdLn.re)
  parity("complex ln(-3+4i) im", toFloat64(cbLn.im), cdLn.im)
  parity("complex abs(-3+4i)", toFloat64(abs(cb)), abs(cd))

proc writeMd() =
  var fp = open("bench/.md_transcendentals.md", fmWrite)
  fp.writeLine("| op | ns/op | ops/sec |")
  fp.writeLine("|---|---|---|")
  for r in mdPerf:
    fp.writeLine("| " & r.name & " | " & r.ns.formatFloat(ffDecimal, 3) &
        " | " &
      r.ops.formatFloat(ffDecimal, 0) & " |")
  fp.close()
  var fa = open("bench/.md_parity.md", fmWrite)
  fa.writeLine("| op | got (BigFloat, 256-bit) | oracle (float64) | \\|err\\| |")
  fa.writeLine("|---|---|---|---|")
  for r in mdParity:
    fa.writeLine("| " & r.name & " | " & r.got.formatFloat(ffDecimal, 15) &
        " | " &
      r.want.formatFloat(ffDecimal, 15) & " | " & r.err.formatFloat(
          ffScientific, 2) & " |")
  fa.close()

when isMainModule:
  runPerf()
  runParity()
  writeMd()
