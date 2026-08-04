# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Splice the arithmetic/transcendental/parity bench markdown fragments
## `nimble bench` wrote (bench/.md_*.md, gitignored) into README.md's
## Benchmarks section, tagged to the machine that ran them.
##
## `<!-- bench:machine=<slug> -->` ... `<!-- /bench:machine=<slug> -->`
## wraps the block. Re-running on the same machine replaces only that
## block; a different slug (or the `UNIMATH_BENCH_MACHINE` env var, for a
## box whose auto-detected slug is not the one you want recorded, e.g. a
## FreeBSD/Zen4 box) appends alongside it -- one README can carry results
## from several machines without one overwriting another's.
import std/[os, osproc, strutils]

proc machineSlug(): string =
  if existsEnv("UNIMATH_BENCH_MACHINE"):
    return getEnv("UNIMATH_BENCH_MACHINE")
  var cpu = hostCPU
  when defined(macosx):
    let (brand, code) = execCmdEx("sysctl -n machdep.cpu.brand_string")
    if code == 0: cpu = brand.strip()
  elif defined(linux):
    let (model, code) = execCmdEx("sh -c \"grep -m1 'model name' /proc/cpuinfo | cut -d: -f2\"")
    if code == 0 and model.strip().len > 0: cpu = model.strip()
  result = (hostOS & "-" & cpu).toLowerAscii().multiReplace(
    (" ", "-"), ("(", ""), (")", ""), ("_", "-"))
  while "--" in result: result = result.replace("--", "-")

proc spliceReadme(slug: string, body: string) =
  const path = "README.md"
  let content = readFile(path)
  let startTag = "<!-- bench:machine=" & slug & " -->"
  let endTag = "<!-- /bench:machine=" & slug & " -->"
  let full = startTag & "\n" & body & "\n" & endTag
  if startTag in content:
    let s = content.find(startTag)
    let e = content.find(endTag) + endTag.len
    writeFile(path, content[0 ..< s] & full & content[e .. ^1])
    stderr.writeLine("[readme] replaced block for " & slug)
  else:
    const marker = "<!-- bench:insert -->"
    if marker notin content:
      stderr.writeLine("[readme] no <!-- bench:insert --> marker in README.md, skip splice")
      return
    let idx = content.find(marker) + marker.len
    writeFile(path, content[0 ..< idx] & "\n\n" & full & content[idx .. ^1])
    stderr.writeLine("[readme] inserted block for " & slug)

proc main() =
  const fragments = [
    ("BigInt / Fixed arithmetic", "bench/.md_arithmetic.md"),
    ("Transcendentals", "bench/.md_transcendentals.md"),
    ("Precision parity: BigFloat (256-bit) vs float64 `math`", "bench/.md_parity.md"),
  ]
  var body = ""
  for (title, path) in fragments:
    if not fileExists(path):
      stderr.writeLine("[readme] missing " & path & " -- run `nimble bench` first")
      quit(1)
    body &= "**" & title & "**\n\n" & readFile(path) & "\n"
  spliceReadme(machineSlug(), body)

when isMainModule:
  main()
