# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[algorithm, json, os, osproc, streams, strutils, times]

const
  DefaultRuns = 3
  DefaultIterations = 20
  PhaseNames = ["direct_transform", "facade_transform", "direct_polar",
    "facade_polar", "regularized_beta"]
  # Metadata plus the result checksum: deterministic, so equal across runs.
  InvariantFields = ["warmup_iterations", "point_count", "semantics", "guard"]

proc median(values: seq[float64]): float64 =
  var ordered = values
  ordered.sort()
  ordered[ordered.len div 2]

proc commandValue(command: string; args: openArray[string]): string =
  try:
    execProcess(command, args = args, options = {poUsePath}).strip
  except OSError:
    "unknown"

proc phaseSummary(reports: seq[JsonNode]; phase: string): JsonNode =
  var means = newSeq[float64](reports.len)
  for index, report in reports:
    means[index] = report[phase]["mean_ms"].getFloat
  %*{
    "run_mean_ms": means,
    "median_run_mean_ms": median(means)
  }

proc runBenchmark(binary: string; iterations: int): string =
  ## Read the output, then reject a failed exit before anything parses it.
  let process = startProcess(binary, args = [$iterations],
    options = {poStdErrToStdOut})
  defer: process.close()
  result = process.outputStream.readAll()
  let code = process.waitForExit()
  if code != 0:
    quit("benchmark process failed (exit " & $code & "): " & result.strip, 1)

proc requireField(node: JsonNode; label, field: string): JsonNode =
  if node.kind != JObject or field notin node:
    quit(label & " lacks a \"" & field & "\" field", 1)
  node[field]

proc validateReport(report: JsonNode; run, iterations: int) =
  ## Run 0 supplies the recorded provenance, so it is checked as strictly as
  ## the runs that are compared against it.
  let label = "run " & $run
  if requireField(report, label, "provider").getStr != "UniMath" or
      requireField(report, label, "operation").getStr !=
        "native-float-facade" or
      requireField(report, label, "iterations").getInt != iterations:
    quit(label & ": benchmark report does not match the requested protocol", 1)
  if requireField(report, label, "warmup_iterations").getInt < 0 or
      requireField(report, label, "point_count").getInt < 1 or
      requireField(report, label, "semantics").getStr.len == 0:
    quit(label & ": benchmark report metadata is unusable", 1)
  discard requireField(report, label, "guard")
  for phase in PhaseNames:
    let summary = requireField(report, label, phase)
    if requireField(summary, label & " " & phase, "mean_ms").getFloat <= 0.0:
      quit(label & ": " & phase & " has no positive mean", 1)

proc main() =
  let params = commandLineParams()
  if params.len > 4:
    quit("usage: run_native_float_baseline [binary] [output] [runs] [iterations]", 2)
  let
    binary = if params.len >= 1: params[0] else:
      "build/benchmark_native_float"
    output = if params.len >= 2: params[1] else:
      "build/native-float-baseline.json"
    runs = if params.len >= 3: parseInt(params[2]) else: DefaultRuns
    iterations = if params.len >= 4: parseInt(params[3]) else:
      DefaultIterations
  if runs < 1 or (runs and 1) == 0 or iterations < 1:
    quit("runs must be positive and odd; iterations must be positive", 2)
  if not fileExists(binary): quit("benchmark binary not found: " & binary, 2)

  var reports = newSeq[JsonNode](runs)
  for run in 0 ..< runs:
    reports[run] = parseJson(runBenchmark(binary, iterations))
    validateReport(reports[run], run, iterations)
    if run > 0:
      for field in InvariantFields:
        if reports[run][field] != reports[0][field]:
          quit("benchmark invariant changed between runs: " & field, 1)

  let
    detectedMachine = when defined(macosx): commandValue("sysctl", ["-n",
      "machdep.cpu.brand_string"])
      else: "unspecified"
    configuredMachine = getEnv("UNIMATH_BENCH_MACHINE")
    machine = if configuredMachine.len > 0: configuredMachine
      elif detectedMachine.len > 0: detectedMachine
      else: "unspecified"
    # The binary is supplied, not built here: only its builder knows the flags.
    configuredBuild = getEnv("UNIMATH_BENCH_BUILD")
    build = if configuredBuild.len > 0: configuredBuild else: "unspecified"
  let report = %*{
    "date": now().format("yyyy-MM-dd"),
    "machine": machine,
    "architecture": hostCPU,
    "os": hostOS,
    "os_version": when defined(macosx): commandValue("sw_vers",
      ["-productVersion"])
      else: "unspecified",
    "nim": NimVersion,
    "build": build,
    "operation": reports[0]["operation"],
    "runs": runs,
    "iterations_per_run": iterations,
    "warmup_iterations": reports[0]["warmup_iterations"],
    "point_count": reports[0]["point_count"],
    "semantics": reports[0]["semantics"],
    "direct_transform": phaseSummary(reports, "direct_transform"),
    "facade_transform": phaseSummary(reports, "facade_transform"),
    "direct_polar": phaseSummary(reports, "direct_polar"),
    "facade_polar": phaseSummary(reports, "facade_polar"),
    "regularized_beta": phaseSummary(reports, "regularized_beta")
  }
  let encoded = pretty(report)
  echo encoded
  writeFile(output, encoded & "\n")

main()
