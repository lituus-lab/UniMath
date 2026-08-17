# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Where does Karatsuba start paying? Sweep `-d:KaratsubaThreshold=N` and read
## the answer off the table instead of guessing it.
##
## The threshold is not a constant of the algorithm. Karatsuba trades one of
## three multiplications for several linear passes, so the faster the basecase,
## the larger an operand must be before that trade pays. When `mulWide` gained
## a native 64x64->128 multiply the basecase roughly halved, and the crossover
## measured here moved from about 48 limbs to about 96 — which made the
## previous threshold of 32 actively harmful in the 32-64 limb range.
##
## Run the sweep with:
##
##     for n in 32 48 64 96 128 192; do
##       nim c -r -d:release -d:KaratsubaThreshold=$n --path:src \
##         -o:build/bk bench/bench_karatsuba.nim
##     done
##
## Not in the default gate: it is a tuning tool, and the answer is per-machine.

import std/[times, monotimes, strformat]
import UniMath/arithmetic/big_int
import UniMath/arithmetic/limbs
import UniMath/arithmetic/multiplication_big

proc ms(d: Duration): float = float(d.inNanoseconds) / 1e6

template timed(body: untyped): float =
  let t0 = getMonoTime()
  body
  ms(getMonoTime() - t0)

var rngState = 0x12345'u64

proc randomBig(words: int): BigUInt =
  var xs = newSeq[Limb](words)
  for i in 0 ..< words:
    rngState = rngState * 6364136223846793005'u64 + 1442695040888963407'u64
    xs[i] = rngState
  xs[^1] = xs[^1] or (1'u64 shl 63) # full width, so `words` is honest
  initBigUInt(xs)

when isMainModule:
  var sink = 0'u64
  echo &"KaratsubaThreshold = {KaratsubaThreshold} limbs " &
       &"({KaratsubaThreshold * LimbBits} bits)"
  echo ""
  echo "| limbs | bits | schoolbook (ns) | mul(Auto) (ns) | Auto/school |"
  echo "|---|---|---|---|---|"
  for words in [8, 16, 24, 32, 48, 64, 96, 128, 192, 256]:
    let a = randomBig(words)
    let b = randomBig(words)
    # Fewer repetitions as the operands grow: the work is quadratic and the
    # point is a stable per-op figure, not a fixed total runtime.
    let reps = max(50, 400_000 div (words * words))
    var school = Inf
    var auto = Inf
    for r in 0 .. 4:
      let t = timed:
        for k in 0 ..< reps: sink += mulSchoolbook(a, b).limbs[0]
      if t < school: school = t
    for r in 0 .. 4:
      let t = timed:
        for k in 0 ..< reps: sink += mul(a, b, Auto).limbs[0]
      if t < auto: auto = t
    let n = float(reps)
    let ratio = auto / school
    let mark = if ratio < 0.98: " **faster**"
               elif ratio > 1.02: " *slower*"
               else: ""
    echo &"| {words} | {words * LimbBits} | {school * 1e6 / n:.0f} | " &
         &"{auto * 1e6 / n:.0f} | {ratio:.2f}{mark} |"
  echo ""
  echo &"(checksum {sink})"
