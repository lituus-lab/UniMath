# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Perf bench for the exact integer / fixed-point cores: BigInt add/mul/div
## (64-bit and 1024-bit), integer sqrt, and Fixed Q32.32 add/mul/div. Reports
## ns/op and ops/sec. Built by `nimble bench`; not in the default gate.
##
## Results feed a non-inline sink that writes a global later printed by the
## harness, so the release optimizer cannot dead-code-eliminate the pure
## `func` bodies (a bare `discard x + y` vanishes and reads as 0 ns/op).
import std/[strutils, times]
import UniMath

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

proc runBenchmarks() =
  echo "UniMath arithmetic benchmarks (release, contracts compiled away)"
  echo repeat('-', 70)

  let a64 = initBigInt(1234567890'i64)
  let b64 = initBigInt(987654321'i64)
  bench("BigInt add (64-bit)", 200000):
    var z = a64 + b64
    keep(cast[int](unsafeAddr(z)))
  bench("BigInt mul (64-bit)", 100000):
    var z = a64 * b64
    keep(cast[int](unsafeAddr(z)))
  let aBig = (initBigInt(1) shl 1024) + initBigInt(123456789'i64)
  let bBig = (initBigInt(1) shl 1024) + initBigInt(987654321'i64)
  bench("BigInt mul (1024-bit)", 20000):
    var z = aBig * bBig
    keep(cast[int](unsafeAddr(z)))
  let aDiv = initBigInt(1234567890123456789'i64)
  let bDiv = initBigInt(987654321'i64)
  bench("BigInt div (64/32-bit)", 50000):
    var z = aDiv div bDiv
    keep(cast[int](unsafeAddr(z)))
  let n = initBigInt(1234567890123456789'i64) * initBigInt(987654321'i64)
  bench("isqrt (BigInt, ~120-bit)", 50000):
    var z = isqrt(n)
    keep(cast[int](unsafeAddr(z)))

  let x = toFixed[int64, 32](123)
  let y = toFixed[int64, 32](789)
  var xa = x
  bench("Fixed Q32.32 add", 1_000_000):
    xa = xa + y # loop-carried: the int64 add cannot be hoisted out of the loop
  bench("Fixed Q32.32 mul", 500_000):
    var z = x * y
    keep(cast[int](unsafeAddr(z)))
  bench("Fixed Q32.32 div", 200_000):
    var z = x / y
    keep(cast[int](unsafeAddr(z)))
  keep(cast[int](unsafeAddr(xa)))

  echo "sink = ", sink # keep every result live across the suite

when isMainModule:
  runBenchmarks()
