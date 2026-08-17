# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Consumer-shaped loops, as opposed to the single-operation timings in
## `bench_arithmetic` and `bench_transcendentals`.
##
## Timing one operation at a time hides the caller's call frames, which cost
## more than a small body. A radix-2 FFT sweep over `Complex[float64]` ran at
## 110 us before the component-wise operators were marked `{.inline.}` and 41.7
## us after, bit-identical; no single-operation benchmark here moved at all.
##
## Not in the default gate. Run explicitly:
##
##     nim c -r -d:release --path:src bench/bench_consumer_loops.nim

import std/[times, monotimes, strutils, math]
import ../src/UniMath

proc ms(d: Duration): float = float(d.inNanoseconds) / 1e6

template timed(body: untyped): float =
  let t0 = getMonoTime()
  body
  ms(getMonoTime() - t0)

const FftPoints = 4096

proc fftPass(a: var seq[Complex[float64]], w: seq[Complex[float64]],
             half: int) =
  ## One decimation-in-time pass: per butterfly, one complex multiply, one
  ## subtract and one add.
  var i = 0
  while i < FftPoints:
    for k in 0 ..< half:
      let t = w[k] * a[i + k + half]
      a[i + k + half] = a[i + k] - t
      a[i + k] = a[i + k] + t
    i += 2 * half

proc benchFft(): tuple[us, checksum: float64] =
  var src = newSeq[Complex[float64]](FftPoints)
  var w = newSeq[Complex[float64]](FftPoints)
  for i in 0 ..< FftPoints:
    src[i] = complex(float64(i mod 97) * 0.01, float64(i mod 43) * 0.02)
    let ang = -2.0 * PI * float64(i) / float64(FftPoints)
    w[i] = complex(cos(ang), sin(ang))

  var checksum = 0.0
  var best = Inf
  for r in 0 .. 4:
    let t = timed:
      for rep in 0 ..< 20:
        var buf = src
        var half = 1
        while half < FftPoints:
          fftPass(buf, w, half)
          half *= 2
        for z in buf: checksum += abs(z.re) + abs(z.im)
    if t < best: best = t
  (best * 1000.0 / 20.0, checksum)

proc benchIntervalChain(): tuple[ns, checksum: float64] =
  ## Interval arithmetic chained the way a range analysis walks an expression.
  const N = 1024
  var a = newSeq[Interval[float64]](N)
  var b = newSeq[Interval[float64]](N)
  for i in 0 ..< N:
    let lo = float64(i mod 31) * 0.1 + 0.5
    a[i] = initInterval(lo, lo + 1.25)
    let mo = float64(i mod 17) * 0.2 + 0.75
    b[i] = initInterval(mo, mo + 0.5)
  var checksum = 0.0
  var best = Inf
  const Reps = 2_000_000
  for r in 0 .. 4:
    var idx = 0
    let t = timed:
      for q in 0 ..< Reps:
        idx = (idx + 1) and (N - 1)
        checksum += ((a[idx] + b[idx]) * b[idx]).lower
    if t < best: best = t
  (best * 1e6 / float(Reps), checksum)

when isMainModule:
  echo "UniMath consumer-loop benchmarks (release)"
  echo "----------------------------------------------------------------------"
  let fft = benchFft()
  echo "Complex[float64] FFT sweep, " & $FftPoints & " points   | " &
       formatFloat(fft.us, ffDecimal, 1) & " us"
  let iv = benchIntervalChain()
  echo "Interval[float64] (a+b)*b chain               | " &
       formatFloat(iv.ns, ffDecimal, 2) & " ns/op"
  echo ""
  echo "checksums (must not move between builds): " &
       formatFloat(fft.checksum, ffDecimal, 6) & " " &
       formatFloat(iv.checksum, ffDecimal, 6)
