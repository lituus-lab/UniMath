# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[json, math, monotimes, os, stats, strutils, times]
import UniMath

const
  PointCount = 262_144
  WarmupIterations = 3

proc elapsedMs(started: MonoTime): float64 =
  inNanoseconds(getMonoTime() - started).float64 / 1_000_000.0

proc directTransform(input: openArray[float64]; output: var seq[float64]) {.
    inline: false.} =
  for index, value in input:
    output[index] = math.sqrt(value) + math.log10(value)

proc facadeTransform(input: openArray[float64]; output: var seq[float64]) {.
    inline: false.} =
  for index, value in input:
    output[index] = sqrt(value) + log10(value)

proc directPolar(input: openArray[float64]; output: var seq[float64]) {.
    inline: false.} =
  for index, value in input:
    output[index] = math.hypot(math.sin(value), math.cos(value))

proc facadePolar(input: openArray[float64]; output: var seq[float64]) {.
    inline: false.} =
  for index, value in input:
    let pair = sinCos(value)
    output[index] = hypot(pair.sin, pair.cos)

proc summary(samples: RunningStat): JsonNode =
  %*{
    "mean_ms": samples.mean,
    "stdev_ms": samples.standardDeviationS,
    "min_ms": samples.min,
    "max_ms": samples.max,
    "million_values_per_second": PointCount.float64 / 1_000.0 / samples.mean
  }

proc checksum(values: openArray[float64]): float64 =
  for value in values: result += value

template measure(milliseconds: untyped; operation: untyped) =
  block:
    let started = getMonoTime()
    operation
    milliseconds = elapsedMs(started)

proc main() =
  let params = commandLineParams()
  if params.len > 2:
    quit("usage: benchmark_native_float [iterations] [output.json]", 2)
  let iterations = if params.len >= 1: parseInt(params[0]) else: 20
  if iterations < 1: quit("iterations must be positive", 2)

  var
    input = newSeq[float64](PointCount)
    directOutput = newSeq[float64](PointCount)
    facadeOutput = newSeq[float64](PointCount)
    directTransformTimes, facadeTransformTimes: RunningStat
    directPolarTimes, facadePolarTimes: RunningStat
  for index in 0 ..< PointCount:
    input[index] = 0.125 + float64(index mod 65_521) / 1024.0

  for iteration in 0 ..< iterations + WarmupIterations:
    var directTransformMs, facadeTransformMs: float64
    if (iteration and 1) == 0:
      measure(directTransformMs): directTransform(input, directOutput)
      measure(facadeTransformMs): facadeTransform(input, facadeOutput)
    else:
      measure(facadeTransformMs): facadeTransform(input, facadeOutput)
      measure(directTransformMs): directTransform(input, directOutput)
    if directOutput != facadeOutput:
      quit("native facade changed transform results", 1)

    var directPolarMs, facadePolarMs: float64
    if (iteration and 1) == 0:
      measure(facadePolarMs): facadePolar(input, facadeOutput)
      measure(directPolarMs): directPolar(input, directOutput)
    else:
      measure(directPolarMs): directPolar(input, directOutput)
      measure(facadePolarMs): facadePolar(input, facadeOutput)
    if directOutput != facadeOutput:
      quit("native facade changed polar results", 1)

    if iteration >= WarmupIterations:
      directTransformTimes.push(directTransformMs)
      facadeTransformTimes.push(facadeTransformMs)
      directPolarTimes.push(directPolarMs)
      facadePolarTimes.push(facadePolarMs)

  let report = %*{
    "provider": "UniMath",
    "operation": "native-float-facade",
    "iterations": iterations,
    "warmup_iterations": WarmupIterations,
    "point_count": PointCount,
    "semantics": "preallocated output; exact same-process result parity",
    "direct_transform": summary(directTransformTimes),
    "facade_transform": summary(facadeTransformTimes),
    "direct_polar": summary(directPolarTimes),
    "facade_polar": summary(facadePolarTimes),
    "guard": checksum(directOutput) + checksum(facadeOutput)
  }
  let encoded = $report
  echo encoded
  if params.len == 2: writeFile(params[1], encoded & "\n")

main()
