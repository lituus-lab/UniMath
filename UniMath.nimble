# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# UniMath — a multi-precision numeric library.

version = "1.0.0"
author = "lituus-lab"
description = "Multi-precision numeric library (Nim + C-ABI + Python)"
license = "Apache-2.0"
srcDir = "src"

requires "nim >= 2.0.0"
requires "https://github.com/lbartoletti/NimContracts#main"
# EFT engine: twoSum/twoProduct and the Shewchuk expansions live here.
requires "https://github.com/lituus-lab/UniAccurate#main"
# Opt-in SIMD backend for the limb-array bitwise ops (`-d:simd`).
requires "https://github.com/lbartoletti/nimsimd#master"

# nimble 0.22 exits 0 even when an `exec` inside a task fails, so a task's exit
# code says nothing about whether its body ran. Each task writes a marker as
# its last statement; `tools/gate.nim` removes the marker, runs the task, and
# fails if it is not there afterwards. `nimble canary` proves the gate still
# bites -- if that one ever passes, every other green result is worthless.
const gateExe =
  when defined(windows): "build/unigate.exe" else: "build/unigate"

template done(task: string) =
  mkDir "build/.gate"
  writeFile("build/.gate/" & task & ".ok", "")

proc gate(task: string): string =
  ## `exec gate("test")` -- builds the tool on first use.
  if not fileExists(gateExe):
    exec "nim c --hints:off -o:" & gateExe & " tools/gate.nim"
  gateExe & " " & task

task canary, "Must fail: proves the gate still catches a broken build":
  # No `done` here on purpose: the exec below raises, so the marker is never
  # written and the gate reports the failure nimble swallowed.
  exec "nim c -r --hints:off --path:src -o:build/canary tests/canary_broken.nim"

task lint, "Fail if nimpretty would reformat a source":
  exec "nim c -r --hints:off -o:build/lint_tool tools/lint.nim"
  done "lint"

task checkVGraph, "Fail on an import that climbs the layers in vgraph.cfg":
  exec "nim c -r --hints:off -o:build/vgraph_tool tools/vgraph.nim"
  done "checkVGraph"

task docsDeps, "Install the docs toolchain (nimib)":
  exec "nimble install -y nimib"
  done "docsDeps"

task book, "Build the nimib book (needs nimib)":
  # nimib compiles and runs the book's code blocks: a drift fails the build.
  exec "nim c -r --path:src --hints:off -o:build/book book/index.nim"
  done "book"

task docs, "API reference + book into pages/ — what CI publishes":
  rmDir "pages"
  exec "nim doc --index:on --outdir:pages/api --project --hints:off src/UniMath.nim"
  exec gate("book")
  # The book is the landing page; the generated reference sits under api/.
  cpFile "book/index.html", "pages/index.html"
  done "docs"

task test, "Nim tests (debug, contracts active)":
  exec "nim c -r --path:src -o:build/test_primitives tests/test_primitives.nim"
  exec "nim c -r --path:src -o:build/test_native_float tests/test_native_float.nim"
  exec "nim c -r --path:src -o:build/test_arithmetic tests/test_arithmetic.nim"
  exec "nim c -r --path:src -o:build/test_fixed tests/test_fixed.nim"
  exec "nim c -r --path:src -o:build/test_float tests/test_float.nim"
  exec "nim c -r --path:src -o:build/test_rational tests/test_rational.nim"
  exec "nim c -r --path:src -o:build/test_interval tests/test_interval.nim"
  exec "nim c -r --path:src -o:build/test_complex tests/test_complex.nim"
  exec "nim c -r --path:src -o:build/test_eft tests/test_eft.nim"
  exec "nim c -r --path:src -o:build/test_roots tests/test_roots.nim"
  exec "nim c -r --path:src -o:build/test_exponential tests/test_exponential.nim"
  exec "nim c -r --path:src -o:build/test_trigonometry tests/test_trigonometry.nim"
  exec "nim c -r --path:src -o:build/test_hyperbolic tests/test_hyperbolic.nim"
  exec "nim c -r --path:src -o:build/test_special tests/test_special.nim"
  exec "nim c -r --path:src -o:build/test_constants tests/test_constants.nim"
  exec "nim c -r --path:src -o:build/test_reduction tests/test_reduction.nim"
  exec "nim c -r --path:src -o:build/test_float_math tests/test_float_math.nim"
  exec "nim c -r --path:src -o:build/test_float_math_precision tests/test_float_math_precision.nim"
  exec "nim c -r --path:src -o:build/test_rational_math tests/test_rational_math.nim"
  exec "nim c -r --path:src -o:build/test_complex_math tests/test_complex_math.nim"
  exec "nim c -r --path:src -o:build/test_math_router tests/test_math_router.nim"
  exec "nim c -r --path:src -o:build/test_conversions tests/test_conversions.nim"
  exec "nim c -r --path:src -o:build/test_properties tests/test_properties.nim"
  done "test"

task testRelease, "Nim tests (release, contracts compiled away)":
  exec "nim c -r -d:release --path:src -o:build/test_primitives_rel tests/test_primitives.nim"
  exec "nim c -r -d:release --path:src -o:build/test_native_float_rel tests/test_native_float.nim"
  exec "nim c -r -d:release --path:src -o:build/test_arithmetic_rel tests/test_arithmetic.nim"
  exec "nim c -r -d:release --path:src -o:build/test_fixed_rel tests/test_fixed.nim"
  exec "nim c -r -d:release --path:src -o:build/test_float_rel tests/test_float.nim"
  exec "nim c -r -d:release --path:src -o:build/test_rational_rel tests/test_rational.nim"
  exec "nim c -r -d:release --path:src -o:build/test_interval_rel tests/test_interval.nim"
  exec "nim c -r -d:release --path:src -o:build/test_complex_rel tests/test_complex.nim"
  exec "nim c -r -d:release --path:src -o:build/test_eft_rel tests/test_eft.nim"
  exec "nim c -r -d:release --path:src -o:build/test_roots_rel tests/test_roots.nim"
  exec "nim c -r -d:release --path:src -o:build/test_exponential_rel tests/test_exponential.nim"
  exec "nim c -r -d:release --path:src -o:build/test_trigonometry_rel tests/test_trigonometry.nim"
  exec "nim c -r -d:release --path:src -o:build/test_hyperbolic_rel tests/test_hyperbolic.nim"
  exec "nim c -r -d:release --path:src -o:build/test_special_rel tests/test_special.nim"
  exec "nim c -r -d:release --path:src -o:build/test_constants_rel tests/test_constants.nim"
  exec "nim c -r -d:release --path:src -o:build/test_reduction_rel tests/test_reduction.nim"
  exec "nim c -r -d:release --path:src -o:build/test_float_math_rel tests/test_float_math.nim"
  exec "nim c -r -d:release --path:src -o:build/test_float_math_precision_rel tests/test_float_math_precision.nim"
  exec "nim c -r -d:release --path:src -o:build/test_rational_math_rel tests/test_rational_math.nim"
  exec "nim c -r -d:release --path:src -o:build/test_complex_math_rel tests/test_complex_math.nim"
  exec "nim c -r -d:release --path:src -o:build/test_math_router_rel tests/test_math_router.nim"
  exec "nim c -r -d:release --path:src -o:build/test_conversions_rel tests/test_conversions.nim"
  exec "nim c -r -d:release --path:src -o:build/test_properties_rel tests/test_properties.nim"
  done "testRelease"

# The 128-bit paths are selected automatically on gcc/clang with a 64-bit
# target, so the portable fallbacks under them are never exercised by the
# default gate on this machine. Without this task they would rot unnoticed.
task testNoInt128, "Limb, arithmetic and fixed suites on the portable fallbacks":
  exec "nim c -r -d:noInt128 --path:src -o:build/test_primitives_p tests/test_primitives.nim"
  exec "nim c -r -d:noInt128 --path:src -o:build/test_arithmetic_p tests/test_arithmetic.nim"
  exec "nim c -r -d:noInt128 --path:src -o:build/test_fixed_p tests/test_fixed.nim"
  exec "nim c -r -d:noInt128 --path:src -o:build/test_rational_p tests/test_rational.nim"
  done "testNoInt128"

task testSimd, "Nim tests with the opt-in SIMD backend (-d:simd)":
  exec "nim c -r -d:simd --path:src -o:build/test_arithmetic_simd tests/test_arithmetic_simd.nim"
  done "testSimd"

# Its own task: the guards only exist under the flag, so the default suites
# compile them out and cannot cover them.
task testChecked, "Fixed-width overflow guards (-d:checkedArithmetic)":
  exec "nim c -r -d:checkedArithmetic --path:src -o:build/test_checked_arithmetic tests/test_checked_arithmetic.nim"
  done "testChecked"

task testCi, "Nim tests (CI subset, debug)":
  exec gate("test")
  done "testCi"

task testCiRelease, "Nim tests (CI subset, release)":
  exec gate("testRelease")
  done "testCiRelease"

task prop, "Randomized property suite (heavy: 2000 iters via -d:propIters)":
  exec "nim c -r -d:release -d:propIters=2000 --path:src -o:build/test_properties_prop tests/test_properties.nim"
  done "prop"

task testAll, "debug + release + checked + portable fallbacks + C ABI + properties":
  exec gate("test")
  exec gate("testRelease")
  exec gate("testNoInt128")
  exec gate("testChecked")
  exec gate("ctest")
  exec gate("prop")
  done "testAll"

task example, "Nim demo":
  exec "nim c -r --path:src -o:build/demo examples/demo.nim"
  done "example"

# Isolated benchmark harness (not in the default gate). Release build so the
# NimContracts `{.contractual.}` procs compile away and the timing reflects the
# shipped code path; the parity section compares BigFloat vs the float64 oracle.
task bench, "Perf + precision-parity benchmarks (release; not in the default gate)":
  exec "nim c -r -d:release --path:src -o:build/bench_arithmetic bench/bench_arithmetic.nim"
  exec "nim c -r -d:release --path:src -o:build/bench_transcendentals bench/bench_transcendentals.nim"
  done "bench"

task benchmarkNativeFloat, "Benchmark the native float64 facade against direct libm calls":
  exec "nim c -d:release --mm:orc --path:src -o:build/benchmark_native_float benchmarks/benchmark_native_float.nim"
  exec "./build/benchmark_native_float"
  done "benchmarkNativeFloat"

task benchmarkNativeFloatBaseline, "Run and aggregate the native float64 baseline":
  exec "nim c -d:release --mm:orc --path:src -o:build/benchmark_native_float benchmarks/benchmark_native_float.nim"
  exec "nim c -d:release --mm:orc -o:build/run_native_float_baseline benchmarks/run_native_float_baseline.nim"
  # The runner records the descriptor it is given; this task is what builds.
  putEnv("UNIMATH_BENCH_BUILD", "-d:release --mm:orc")
  exec "./build/run_native_float_baseline"
  done "benchmarkNativeFloatBaseline"

# Consumer-shaped loops rather than single operations: a call frame per
# operation is invisible to every other benchmark here. Not in the default gate.
task benchConsumer, "Consumer-loop benchmarks (FFT, interval chains)":
  exec "nim c -r -d:release --path:src -o:build/bench_consumer bench/bench_consumer_loops.nim"
  done "benchConsumer"

task benchReadme, "bench (+ benchSpeed if libmpc/libmpfr/libgmp are available), splice into README.md":
  exec gate("bench")
  let (_, pkgCode) = gorgeEx("pkg-config --exists mpc mpfr gmp")
  if pkgCode == 0:
    # Build only (no `make run`), then execute directly so the captured file
    # is the C binary's own stdout, not nimble/make's build chatter too.
    exec gate("clibStatic")
    exec "make -C bench bench_speed"
    exec "./bench/bench_speed > bench/.md_speed.txt"
  else:
    echo "benchReadme: no libmpc/libmpfr/libgmp -- skipping the oracle comparison"
  exec "nim c -r --path:src bench/export_readme.nim"
  done "benchReadme"

# Nim takes `-o:` literally and appends no platform extension.
const
  sharedLib =
    when defined(windows): "libUniMath.dll"
    elif defined(macosx): "libUniMath.dylib"
    else: "libUniMath.so"
  staticLib = "libUniMath.a" # MinGW `ar` on Windows, so `.a` everywhere.

  # @rpath install_name, so the copy bundled in the wheel is found at import.
  macArgs =
    when defined(macosx): " --passL:\"-Wl,-install_name,@rpath/" & sharedLib & "\""
    else: ""

# --panics:off (the Nim default, pinned here): c_api returns sentinels by
# catching Defect sites, which --panics:on would turn into process aborts.
task clib, "C shared library":
  exec "nim c --app:lib --noMain --mm:arc --panics:off -d:release -o:" & sharedLib & macArgs &
       " src/UniMath/c_api.nim"
  done "clib"

task clibStatic, "C static library":
  exec "nim c --app:staticlib -d:staticNoAutoInit --noMain --mm:arc --panics:off -d:release -o:" & staticLib &
       " src/UniMath/c_api.nim"
  done "clibStatic"

task clibMsvc, "C static library, MSVC ABI (Windows Python extension)":
  # CPython on Windows is MSVC-built and cannot link MinGW output.
  exec "nim c --cc:vcc --app:staticlib -d:staticNoAutoInit --noMain --mm:arc --panics:off -d:release" &
       " -o:UniMath.lib src/UniMath/c_api.nim"
  done "clibMsvc"

# Nim's MinGW toolchain names it mingw32-make.
let makeExe = if findExe("mingw32-make").len > 0: "mingw32-make" else: "make"

# tests/c and examples/c are POSIX-portable Makefiles carrying no OS branch
# (GNU and BSD make share no conditional syntax), so the Windows names come
# from here as command-line assignments, which beat `?=` on every make flavor.
# `del` needs no `/q`: it is only ever handed a single name, never a wildcard.
proc winMakeVars(bin: string): string =
  when defined(windows):
    " CC=gcc BIN=" & bin & ".exe RUN=" & bin & ".exe RM_F=del"
  else:
    ""

# `make -C`, not `cd dir && make`: nimble's exec runs no shell on Windows.
task ctest, "C ABI tests":
  exec gate("clibStatic")
  exec makeExe & " -C tests/c" & winMakeVars("test_unimath")
  done "ctest"

task cexample, "C demo":
  exec gate("clibStatic")
  exec makeExe & " -C examples/c" & winMakeVars("demo")
  done "cexample"

# Head-to-head speed vs the native GMP/MPFR/MPC oracles at matching precision.
# Linux/macOS only (needs libmpc/libmpfr/libgmp via pkg-config); NOT in the
# default gate — run `nimble benchSpeed` explicitly. Builds the static lib,
# compiles bench/bench_speed.c against it + libmpc + libmpfr + libgmp, and runs
# the comparison.
task benchSpeed, "UniMath-vs-GMP/MPFR/MPC speed benchmark (needs libmpc/libmpfr/libgmp; not in the default gate)":
  exec gate("clibStatic")
  exec makeExe & " -C bench"
  done "benchSpeed"

# Native oracles: independent MPFR/GMP/MPC references for the exact-type,
# transcendental and complex tests. Linux/macOS only (need libmpc/libmpfr/
# libgmp via pkg-config); NOT in the default gate — run `nimble testOracle`
# explicitly. The C binaries
# are gitignored; lint does not scan oracles/ (only src/tests/examples/book).
task buildOracles, "Build the MPFR, GMP and MPC C oracles (needs libmpfr/libgmp/libmpc)":
  exec "cc -O2 -std=c11 -o oracles/mpfr_oracle oracles/mpfr_oracle.c " &
       "$(pkg-config --cflags --libs mpfr gmp)"
  exec "cc -O2 -std=c11 -o oracles/gmp_oracle oracles/gmp_oracle.c " &
       "$(pkg-config --cflags --libs gmp)"
  # MPC is MPFR's complex counterpart: the independent reference for Complex.
  exec "cc -O2 -std=c11 -o oracles/mpc_oracle oracles/mpc_oracle.c " &
       "$(pkg-config --cflags --libs mpc mpfr gmp)"
  done "buildOracles"

task testOracle, "Oracle tests — GMP/MPFR/MPC/EFT (needs libmpc/libmpfr/libgmp; not in the default gate)":
  exec gate("buildOracles")
  exec "nim c -r --path:. --hints:off -o:build/test_oracle tests/test_oracle_smoke.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_gmp_oracle tests/test_gmp_oracle.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_fixed_oracle tests/test_fixed_oracle.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_bigfloat_oracle tests/test_bigfloat_oracle.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_float_math_oracle tests/test_float_math_oracle.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_rational_oracle tests/test_rational_oracle.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_complex_oracle tests/test_complex_oracle.nim"
  done "testOracle"

# The Windows launcher is `python`; `python3` only exists elsewhere.
const pyExe = when defined(windows): "python" else: "python3"

task pyDeps, "Install Python build deps (setuptools, Cython, pytest) if missing":
  exec pyExe & " -m pip install --break-system-packages --quiet setuptools wheel \"Cython>=3.0.0\" pytest"
  done "pyDeps"

# The extension links the vcc static lib on Windows, the shared lib elsewhere.
task pyLib, "Build the library the Python extension links against":
  when defined(windows):
    exec gate("clibMsvc")
  else:
    exec gate("clib")
  done "pyLib"

# `withDir`, not `cd py && ...`: nimble's exec runs no shell on Windows.
task buildCython, "Cython extension in-place":
  exec gate("pyLib")
  exec gate("pyDeps")
  withDir "py":
    exec pyExe & " setup.py build_ext --inplace"
  done "buildCython"

task pyTest, "Cython extension + pytest":
  exec gate("buildCython")
  withDir "py":
    exec pyExe & " -m pytest -q"
  done "pyTest"

task pyWheel, "wheel":
  exec gate("pyLib")
  exec gate("pyDeps")
  withDir "py":
    exec pyExe & " setup.py bdist_wheel"
  done "pyWheel"

task coverage, "LCOV + HTML coverage report for the Nim sources (needs lcov)":
  # gcov and lcov driven directly, no coco. Linux and macOS only.
  # --debugger:native attributes lines to the .nim sources, not the generated C.
  # --include keeps stdlib out of the capture, where lcov 2.x aborts on Nim's
  # codegen. Together they leave nothing to suppress: no --ignore-errors here,
  # so a real problem still fails the build.
  let cache = "build/covcache"
  rmDir cache
  rmDir "coverage"
  exec "nim c --path:src --nimcache:" & cache &
       " --debugger:native --passC:--coverage --passL:--coverage" &
       " -o:build/test_coverage tests/test_arithmetic.nim"
  exec "./build/test_coverage"
  exec "lcov --capture --directory " & cache & " --base-directory ." &
       " --include \"*/src/UniMath/*\" --output-file lcov.info --quiet"
  exec "genhtml lcov.info --output-directory coverage --legend --quiet"
  exec "lcov --summary lcov.info"
  done "coverage"
