# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Oracle bridge for UniMath correctness tests.
##
## Calls the native MPFR transcendental oracle (`oracles/mpfr_oracle`), the
## native GMP exact-arithmetic oracle (`oracles/gmp_oracle`) and the native MPC
## complex oracle (`oracles/mpc_oracle`), all built by `nimble buildOracles`,
## plus the Python decimal EFT oracle
## (`oracles/eft_oracle.py`). The C oracles are separate processes driven by a
## text stdin/stdout protocol — NO Nim `seq`/`string` ever crosses an ABI
## boundary; only line text is exchanged over pipes, so the bridge is ABI-safe
## by construction (the UniAccurate oracle pattern).
##
## MPFR verifies the BigFloat transcendentals — sin/cos/exp/ln/sqrt/gamma —
## both as the correctly-rounded float64 reference and as an exact
## (abs/rel/ulp) error of a candidate vs the 2048-bit exact real value. GMP is
## the independent cross-check (different library) of the exact-type
## arithmetic: BigInt divmod reconstruction, Fixed `*`/`/`, and Rational
## cross-multiply comparison. MPC is MPFR's complex counterpart and verifies
## the `Complex` transcendentals. The decimal EFT oracle is the last-bit
## reference for the twoSum/twoDiff/twoProduct identity.
##
## Build the C executables first: `nimble buildOracles` (requires libmpc/
## libmpfr/libgmp via pkg-config). The C binaries are gitignored build
## artifacts; if missing, the bridge raises with a clear build hint.
import std/[os, osproc, streams, strutils]

const oraclesDir = currentSourcePath().parentDir()

proc mpfrExe*: string = oraclesDir / "mpfr_oracle"
proc gmpExe*: string = oraclesDir / "gmp_oracle"

const OracleChunkBytes = 8192
  ## Upper bound on the input handed to one oracle invocation. The child emits
  ## a line while it reads, so writing a whole large batch before reading any
  ## output deadlocks: the child fills the stdout pipe (commonly 64 KiB),
  ## blocks in `write`, stops draining stdin, and the parent then blocks
  ## writing to a full stdin pipe. Bounding the input keeps both directions
  ## inside one buffer. The public batch APIs invite inputs well past that.

proc runCOracleOnce(exe, input: string): seq[string] =
  var p = startProcess(exe, "", [], nil, {poUsePath})
  # `try/finally` so a write/read exception still reaps the child and closes
  # the pipe handles — no leaked process or FD if the oracle misbehaves.
  try:
    p.inputStream.write(input)
    p.inputStream.close() # EOF: tells the C process no more input
    let output = p.outputStream.readAll()
    let rc = p.waitForExit()
    if rc != 0:
      raise newException(ValueError, exe & " exited with " & $rc & ":\n" & output)
    for line in output.splitLines():
      if line.strip != "":
        result.add(line)
  finally:
    p.close()

proc runCOracle*(exe, input: string): seq[string] =
  ## Send `input` (stdin lines) to a compiled C oracle `exe`; return the
  ## non-empty output lines in order. Raises `ValueError` on non-zero exit or
  ## if the executable is missing (build it with the nimble task). Large inputs
  ## are split across several invocations (see `OracleChunkBytes`).
  if not fileExists(exe):
    raise newException(ValueError,
      "Oracle executable not found at " & exe & ". Build it with " &
      "`nimble buildOracles` (requires libmpc/libmpfr/libgmp via pkg-config).")
  if input.len == 0:
    return
  if input.len <= OracleChunkBytes:
    return runCOracleOnce(exe, input)
  var chunk = ""
  for line in input.splitLines():
    if line.len == 0: continue
    if chunk.len > 0 and chunk.len + line.len + 1 > OracleChunkBytes:
      result.add(runCOracleOnce(exe, chunk))
      chunk.setLen(0)
    chunk.add(line)
    chunk.add('\n')
  if chunk.len > 0:
    result.add(runCOracleOnce(exe, chunk))

# =============================================================================
# MPFR transcendental oracle
# =============================================================================

const TranscOps = ["sin", "cos", "exp", "ln", "sqrt", "gamma"]

proc checkOp(op: string) =
  if op notin TranscOps:
    raise newException(ValueError, "mpfr oracle: unknown op '" & op & "'")

proc checkPrec(prec: int) {.inline.} =
  ## Reject MPFR and MPC working precisions that would make the float64
  ## reference a DOUBLE rounding instead of a correctly-rounded binary64.
  ##
  ## The C oracle computes R = RN_prec(op(x)) (MPFR correctly rounds each
  ## transcendental to `prec` bits), then `mpfr_get_d` rounds R to binary64:
  ## result = RN_53(RN_prec(op(x))). Two successive roundings equal a single
  ## RN_53(op(x)) ONLY when the intermediate precision is large enough that
  ## the prec-bit rounding cannot create a binary64 halfway tie — the standard
  ## double-rounding theorem (Goldberg §4; Sterbenz) guarantees this when
  ## `prec >= 2*53 = 106`. At `prec == 53` the second rounding is exact (the
  ## value is already binary64), so it is also a single rounding. For
  ## `53 < prec < 107` the reference may differ from the true
  ## correctly-rounded binary64 by up to 1 ulp in rare cases, so a candidate
  ## compared against it would be misjudged. Reject that band (1 guard bit
  ## above 106 → 107); the suite's `RefPrec = 2048` is well inside the safe
  ## zone. The error modes (`mpfrErr`, `mpcErr` and their batches) fix their
  ## own ACC_PREC = 2048 and are unaffected.
  if prec == 53 or prec >= 107: return
  raise newException(ValueError,
    "oracle: prec " & $prec & " is in the double-rounding band (53, 107); " &
    "use 53 (direct binary64) or >= 107 (2*53 + guard) for a " &
    "correctly-rounded float64 reference")

proc mpfrRefBatch*(queries: openArray[(string, int, float64)]): seq[float64] =
  ## Batch of correctly-rounded float64 references. Each query is (op, prec, x):
  ## the round-to-nearest-even of op(x) to binary64, computed by MPFR at
  ## `prec` bits. `x` is sent as its raw IEEE bit pattern (exact). Only finite
  ## float64 arguments with a finite result; domain errors (sqrt/ln of
  ## non-positive, gamma poles) make the oracle exit non-zero and raise here.
  ##
  ## `prec` must be 53 or >= 107: the in-between band double-rounds and is
  ## rejected by `checkPrec` (the result would not be a correctly-rounded
  ## binary64, defeating the oracle's purpose).
  if queries.len == 0: return
  let exe = mpfrExe()
  var input = ""
  for (op, prec, x) in queries:
    checkOp(op)
    checkPrec(prec)
    input.add(op & " " & $prec & " " & $cast[uint64](x) & "\n")
  let lines = runCOracle(exe, input)
  if lines.len != queries.len:
    raise newException(ValueError, "mpfr_oracle returned " & $lines.len &
      " results for " & $queries.len & " queries:\n" & lines.join("\n"))
  for line in lines:
    result.add cast[float64](parseUInt(line).uint64)

proc mpfrRef*(op: string, prec: int, x: float64): float64 {.inline.} =
  ## Single correctly-rounded float64 reference for op(x). `prec` must be 53
  ## or >= 107 (see `mpfrRefBatch` — the (53, 107) band double-rounds).
  mpfrRefBatch(@[(op, prec, x)])[0]

proc mpfrErrBatch*(queries: openArray[(string, int, float64, float64)]):
    seq[(float64, float64, float64)] =
  ## Batch of exact error measurements. Each query is (op, prec, cand, x):
  ## the candidate `cand` (a float64, sent as raw bits) is compared to the
  ## 2048-bit exact real value R = op(x). Returns one (abs_err, rel_err,
  ## ulp_err) triple per query, in order — exact (no float-subtraction
  ## rounding), ulp measured at the magnitude of R (Goldberg/Muller). A
  ## correctly-rounded candidate reports ulp_err <= 0.5; faithful <= 1.
  if queries.len == 0: return
  let exe = mpfrExe()
  var input = ""
  for (op, prec, cand, x) in queries:
    checkOp(op)
    input.add("err " & op & " " & $prec & " " & $cast[uint64](cand) & " " &
              $cast[uint64](x) & "\n")
  let lines = runCOracle(exe, input)
  if lines.len != queries.len:
    raise newException(ValueError, "mpfr_oracle err returned " & $lines.len &
      " lines for " & $queries.len & " queries:\n" & lines.join("\n"))
  for line in lines:
    let p = line.splitWhitespace()
    if p.len < 3:
      raise newException(ValueError, "bad err output line: " & line)
    result.add((parseFloat(p[0]), parseFloat(p[1]), parseFloat(p[2])))

proc mpfrErr*(op: string, prec: int, cand, x: float64):
    (float64, float64, float64) {.inline.} =
  ## Single exact error triple (abs_err, rel_err, ulp_err) for cand vs op(x).
  mpfrErrBatch(@[(op, prec, cand, x)])[0]

# Binary arithmetic oracle (BigFloat + - * /): independent MPFR reference for
# two-operand ops. `bin` is the correctly-rounded float64 of a op b; `berr` is
# the exact (abs, rel, ulp) error of a candidate vs the 2048-bit exact result.

const BinOps = ["add", "sub", "mul", "div"]

proc checkBinOp(op: string) =
  if op notin BinOps:
    raise newException(ValueError, "mpfr oracle: unknown binary op '" & op & "'")

proc mpfrBinRefBatch*(queries: openArray[(string, int, float64, float64)]):
    seq[float64] =
  ## Batch of correctly-rounded float64 references for binary ops. Each query
  ## is (op, prec, a, b): round-to-nearest-even of `a op b` to binary64, from
  ## MPFR at `prec` bits (prec must be 53 or >= 107 — see `checkPrec`).
  if queries.len == 0: return
  let exe = mpfrExe()
  var input = ""
  for (op, prec, a, b) in queries:
    checkBinOp(op)
    checkPrec(prec)
    input.add("bin " & op & " " & $prec & " " & $cast[uint64](a) & " " &
              $cast[uint64](b) & "\n")
  let lines = runCOracle(exe, input)
  if lines.len != queries.len:
    raise newException(ValueError, "mpfr_oracle bin returned " & $lines.len &
      " results for " & $queries.len & " queries:\n" & lines.join("\n"))
  for line in lines:
    result.add cast[float64](parseUInt(line).uint64)

proc mpfrBinRef*(op: string, prec: int, a, b: float64): float64 {.inline.} =
  ## Single correctly-rounded float64 reference for `a op b`.
  mpfrBinRefBatch(@[(op, prec, a, b)])[0]

proc mpfrBinErrBatch*(queries: openArray[(string, int, float64, float64, float64)]):
    seq[(float64, float64, float64)] =
  ## Batch of exact error triples for binary ops. Each query is
  ## (op, prec, cand, a, b): (abs_err, rel_err, ulp_err) of `cand` vs the
  ## 2048-bit exact `a op b`. A correctly-rounded cand reports ulp_err <= 0.5.
  if queries.len == 0: return
  let exe = mpfrExe()
  var input = ""
  for (op, prec, cand, a, b) in queries:
    checkBinOp(op)
    input.add("berr " & op & " " & $prec & " " & $cast[uint64](cand) & " " &
              $cast[uint64](a) & " " & $cast[uint64](b) & "\n")
  let lines = runCOracle(exe, input)
  if lines.len != queries.len:
    raise newException(ValueError, "mpfr_oracle berr returned " & $lines.len &
      " lines for " & $queries.len & " queries:\n" & lines.join("\n"))
  for line in lines:
    let p = line.splitWhitespace()
    if p.len < 3:
      raise newException(ValueError, "bad berr output line: " & line)
    result.add((parseFloat(p[0]), parseFloat(p[1]), parseFloat(p[2])))

proc mpfrBinErr*(op: string, prec: int, cand, a, b: float64):
    (float64, float64, float64) {.inline.} =
  ## Single exact error triple for `cand` vs `a op b`.
  mpfrBinErrBatch(@[(op, prec, cand, a, b)])[0]

# =============================================================================
# GMP exact-arithmetic oracle (BigInt / Rational / Fixed)
# =============================================================================

proc gmpLine*(line: string): string =
  ## Run a single GMP oracle query line; return its single output line.
  let lines = runCOracle(gmpExe(), line & "\n")
  if lines.len != 1:
    raise newException(ValueError, "gmp_oracle returned " & $lines.len &
      " lines for query '" & line & "'")
  lines[0]

proc gmpBinop*(op, a, b: string): string =
  ## `add`/`sub`/`mul` of two signed decimal integers (unbounded).
  gmpLine(op & " " & a & " " & b)

proc gmpDivMod*(a, b: string): (string, string) =
  ## Signed Euclidean divmod (truncated toward zero): returns (quo, rem).
  let p = gmpLine("divmod " & a & " " & b).splitWhitespace()
  if p.len < 2: raise newException(ValueError, "bad divmod output")
  (p[0], p[1])

proc gmpUDivMod*(a, b: string): (string, string) =
  ## Unsigned divmod (a, b >= 0, floor): returns (quo, rem).
  let p = gmpLine("udivmod " & a & " " & b).splitWhitespace()
  if p.len < 2: raise newException(ValueError, "bad udivmod output")
  (p[0], p[1])

proc gmpReconstruct*(a, b, q, r: string): bool =
  ## Convention-agnostic reconstruction check: a == q*b + r and |r| < |b|.
  gmpLine("reconstruct " & a & " " & b & " " & q & " " & r).startsWith("OK")

proc gmpCmp*(a, b: string): int =
  ## Signed integer comparison: -1 / 0 / 1.
  parseInt(gmpLine("cmp " & a & " " & b))

proc gmpRationalCmp*(na, da, nb, db: string): int =
  ## Rational comparison na/da vs nb/db (mpq, auto-reduced): -1 / 0 / 1.
  parseInt(gmpLine("rcmp " & na & " " & da & " " & nb & " " & db))

proc gmpRationalOp*(op, na, da, nb, db: string): (string, string) =
  ## `radd`/`rsub`/`rmul` of two rationals; returns (num, den) reduced.
  let p = gmpLine(op & " " & na & " " & da & " " & nb & " " &
      db).splitWhitespace()
  if p.len < 2: raise newException(ValueError, "bad rational op output")
  (p[0], p[1])

proc gmpFixedMul*(frac: int, a, b: string): string =
  ## Fixed `*`: (a*b) >> frac (arithmetic shift / floor) — exact GMP reference.
  gmpLine("fmul " & $frac & " " & a & " " & b)

proc gmpFixedDiv*(frac: int, a, b: string): string =
  ## Fixed `/`: (a << frac) / b (truncated toward zero) — exact GMP reference.
  gmpLine("fdiv " & $frac & " " & a & " " & b)

# =============================================================================
# Python decimal EFT oracle (twoSum / twoDiff / twoProduct head+tail == exact)
# =============================================================================
# `oracles/eft_oracle.py` computes, with `decimal.Decimal` at prec=800, the
# correctly-rounded result `s = round(a op b)` and the EXACT rounding error
# `e = (a op b) - s` (representable under IEEE-754 roundTiesToEven), for
# float64 and float32. This is the last-bit reference for the EFT identity
# `s + e == a op b` that a float-level contract cannot check. One python3
# subprocess per batch; only line text crosses the pipe (no ABI boundary).

proc runPyOracle*(script, input: string): seq[string] =
  ## Send `input` (stdin lines) to a Python oracle `script`; return the
  ## non-empty output lines in order. Raises `ValueError` on non-zero exit.
  if input.len == 0: return
  if not fileExists(script):
    raise newException(ValueError, "Python oracle not found at " & script)
  var p = startProcess("python3", "", [script], nil, {poUsePath})
  try:
    p.inputStream.write(input)
    p.inputStream.close()
    let output = p.outputStream.readAll()
    let rc = p.waitForExit()
    if rc != 0:
      raise newException(ValueError, script & " exited with " & $rc & ":\n" & output)
    for line in output.splitLines():
      if line.strip != "":
        result.add(line)
  finally:
    p.close()

proc eftOracle*(queries: openArray[(string, float64, float64)];
                asF32 = false): seq[(float64, float64)] =
  ## Batch of exact EFT references. Each query is (op, a, b) with op in
  ## {"sum", "diff", "prod"}; returns the (s, e) pairs in order, where
  ## `s = round_to_nearest(a op b)` and `e = (a op b) - s` (exact). With
  ## `asF32 = true`, rounding is to binary32 and the returned float64 values
  ## equal the float32 results bit-for-bit (f32->f64 widening is exact).
  ## Feed only finite a, b with a finite, non-overflowing exact result.
  if queries.len == 0: return
  let script = oraclesDir / "eft_oracle.py"
  var input = ""
  for (op, a, b) in queries:
    input.add(op & " " & $a & " " & $b & (if asF32: " f32" else: "") & "\n")
  let lines = runPyOracle(script, input)
  if lines.len != queries.len:
    raise newException(ValueError, "eft_oracle.py returned " & $lines.len &
      " results for " & $queries.len & " queries:\n" & lines.join("\n"))
  for line in lines:
    let p = line.splitWhitespace()
    if p.len < 2:
      raise newException(ValueError, "bad eft oracle output line: " & line)
    result.add((parseFloat(p[0]), parseFloat(p[1])))

# =============================================================================
# MPC complex oracle
# =============================================================================
#
# MPC is MPFR's complex counterpart (same authors, same build system), so the
# reference for `Complex[float64]` is independent of the library under test in
# exactly the way ADR-0008 asks. Values cross as the raw IEEE-754 bit patterns
# of their components -- exact, no decimal round-trip.
#
# The branch cuts agree by construction: MPC takes the principal values, arg
# in (-pi, pi], cut along the negative real axis, which is what `complex_math`
# documents. MPC honours signed zero and UniMath deliberately does not, so
# never send a negative zero imaginary part.

proc mpcExe*: string = oraclesDir / "mpc_oracle"

const
  MpcUnaryOps = ["sqrt", "exp", "log", "sin", "cos", "tan", "sinh", "cosh",
                 "tanh"]
  MpcBinOps = ["add", "sub", "mul", "div", "pow"]
  MpcRealOps = ["abs", "arg"]

proc checkMpcOp(op: string, allowed: openArray[string]) =
  if op notin allowed:
    raise newException(ValueError, "mpc oracle: unknown op '" & op & "'")

proc bitsOf(x: float64): string {.inline.} = $cast[uint64](x)

proc parseComplexLine(line: string): (float64, float64) =
  let p = line.splitWhitespace()
  if p.len < 2:
    raise newException(ValueError, "bad mpc oracle output line: " & line)
  (cast[float64](parseUInt(p[0]).uint64), cast[float64](parseUInt(p[1]).uint64))

proc mpcRefBatch*(queries: openArray[(string, int, float64, float64)]):
    seq[(float64, float64)] =
  ## Batch of correctly-rounded complex references. Each query is
  ## (op, prec, re, im): the round-to-nearest-even of op(re + im*i) to a pair
  ## of binary64s, computed by MPC at `prec` bits. Domain errors (log of the
  ## complex zero) make the oracle exit non-zero and raise here.
  if queries.len == 0: return
  var input = ""
  for (op, prec, re, im) in queries:
    checkMpcOp(op, MpcUnaryOps)
    checkPrec(prec)
    input.add(op & " " & $prec & " " & bitsOf(re) & " " & bitsOf(im) & "\n")
  let lines = runCOracle(mpcExe(), input)
  if lines.len != queries.len:
    raise newException(ValueError, "mpc_oracle returned " & $lines.len &
      " results for " & $queries.len & " queries:\n" & lines.join("\n"))
  for line in lines:
    result.add parseComplexLine(line)

proc mpcRef*(op: string, prec: int, re, im: float64): (float64, float64) {.inline.} =
  ## Single correctly-rounded complex reference for op(re + im*i).
  mpcRefBatch(@[(op, prec, re, im)])[0]

proc mpcBinRefBatch*(queries: openArray[(string, int, float64, float64,
                                         float64, float64)]):
    seq[(float64, float64)] =
  ## Batch of correctly-rounded references for the binary ops. Each query is
  ## (op, prec, a_re, a_im, b_re, b_im); `op` in {add, sub, mul, div, pow}.
  ## Division by the complex zero, and `pow` of a zero base, are domain errors.
  if queries.len == 0: return
  var input = ""
  for (op, prec, aRe, aIm, bRe, bIm) in queries:
    checkMpcOp(op, MpcBinOps)
    checkPrec(prec)
    input.add("bin " & op & " " & $prec & " " & bitsOf(aRe) & " " &
              bitsOf(aIm) & " " & bitsOf(bRe) & " " & bitsOf(bIm) & "\n")
  let lines = runCOracle(mpcExe(), input)
  if lines.len != queries.len:
    raise newException(ValueError, "mpc_oracle bin returned " & $lines.len &
      " results for " & $queries.len & " queries:\n" & lines.join("\n"))
  for line in lines:
    result.add parseComplexLine(line)

proc mpcBinRef*(op: string, prec: int, aRe, aIm, bRe, bIm: float64):
    (float64, float64) {.inline.} =
  mpcBinRefBatch(@[(op, prec, aRe, aIm, bRe, bIm)])[0]

proc mpcRealRefBatch*(queries: openArray[(string, int, float64, float64)]):
    seq[float64] =
  ## Batch of correctly-rounded REAL references: `abs` (modulus) and `arg`
  ## (principal argument) of the complex argument.
  if queries.len == 0: return
  var input = ""
  for (op, prec, re, im) in queries:
    checkMpcOp(op, MpcRealOps)
    checkPrec(prec)
    input.add("real " & op & " " & $prec & " " & bitsOf(re) & " " &
              bitsOf(im) & "\n")
  let lines = runCOracle(mpcExe(), input)
  if lines.len != queries.len:
    raise newException(ValueError, "mpc_oracle real returned " & $lines.len &
      " results for " & $queries.len & " queries:\n" & lines.join("\n"))
  for line in lines:
    result.add cast[float64](parseUInt(line).uint64)

proc mpcRealRef*(op: string, prec: int, re, im: float64): float64 {.inline.} =
  mpcRealRefBatch(@[(op, prec, re, im)])[0]

proc mpcErrBatch*(queries: openArray[(string, float64, float64, float64,
                                      float64)]):
    seq[(float64, float64)] =
  ## Batch of exact error measurements. Each query is
  ## (op, cand_re, cand_im, re, im): the candidate is compared to the 2048-bit
  ## exact value R = op(re + im*i). Returns one (abs_err, rel_err) pair per
  ## query, both measured as complex moduli and computed without the rounding
  ## a float64 subtraction would add.
  if queries.len == 0: return
  var input = ""
  for (op, candRe, candIm, re, im) in queries:
    checkMpcOp(op, MpcUnaryOps)
    # The precision field is ignored in err mode (it always accumulates at
    # ACC_PREC), but the protocol keeps the slot so every line parses alike.
    input.add("err " & op & " 2048 " & bitsOf(candRe) & " " & bitsOf(candIm) &
              " " & bitsOf(re) & " " & bitsOf(im) & "\n")
  let lines = runCOracle(mpcExe(), input)
  if lines.len != queries.len:
    raise newException(ValueError, "mpc_oracle err returned " & $lines.len &
      " lines for " & $queries.len & " queries:\n" & lines.join("\n"))
  for line in lines:
    let p = line.splitWhitespace()
    if p.len < 2:
      raise newException(ValueError, "bad mpc err output line: " & line)
    result.add((parseFloat(p[0]), parseFloat(p[1])))

proc mpcErr*(op: string, candRe, candIm, re, im: float64):
    (float64, float64) {.inline.} =
  ## Single exact (abs_err, rel_err) pair for a candidate vs op(re + im*i).
  mpcErrBatch(@[(op, candRe, candIm, re, im)])[0]
