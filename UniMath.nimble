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

task lint, "Fail if nimpretty would reformat a source":
  exec "nim c -r --hints:off -o:build/lint_tool tools/lint.nim"

task checkVGraph, "Fail on an import that climbs the layers in vgraph.cfg":
  exec "nim c -r --hints:off -o:build/vgraph_tool tools/vgraph.nim"

task docsDeps, "Install the docs toolchain (nimib)":
  exec "nimble install -y nimib"

task book, "Build the nimib book (needs nimib)":
  # nimib compiles and runs the book's code blocks: a drift fails the build.
  exec "nim c -r --path:src --hints:off -o:build/book book/index.nim"

task docs, "API reference + book into pages/ — what CI publishes":
  rmDir "pages"
  exec "nim doc --index:on --outdir:pages/api --project --hints:off src/UniMath.nim"
  exec "nimble book"
  # The book is the landing page; the generated reference sits under api/.
  cpFile "book/index.html", "pages/index.html"

task test, "Nim tests (debug, contracts active)":
  exec "nim c -r --path:src -o:build/test_arithmetic tests/test_arithmetic.nim"
  exec "nim c -r --path:src -o:build/test_fixed tests/test_fixed.nim"
  exec "nim c -r --path:src -o:build/test_float tests/test_float.nim"
  exec "nim c -r --path:src -o:build/test_rational tests/test_rational.nim"
  exec "nim c -r --path:src -o:build/test_interval tests/test_interval.nim"
  exec "nim c -r --path:src -o:build/test_eft tests/test_eft.nim"
  exec "nim c -r --path:src -o:build/test_roots tests/test_roots.nim"
  exec "nim c -r --path:src -o:build/test_exponential tests/test_exponential.nim"
  exec "nim c -r --path:src -o:build/test_trigonometry tests/test_trigonometry.nim"
  exec "nim c -r --path:src -o:build/test_hyperbolic tests/test_hyperbolic.nim"
  exec "nim c -r --path:src -o:build/test_special tests/test_special.nim"
  exec "nim c -r --path:src -o:build/test_constants tests/test_constants.nim"
  exec "nim c -r --path:src -o:build/test_reduction tests/test_reduction.nim"
  exec "nim c -r --path:src -o:build/test_float_math tests/test_float_math.nim"
  exec "nim c -r --path:src -o:build/test_rational_math tests/test_rational_math.nim"
  exec "nim c -r --path:src -o:build/test_math_router tests/test_math_router.nim"
  exec "nim c -r --path:src -o:build/test_conversions tests/test_conversions.nim"
  exec "nim c -r --path:src -o:build/test_properties tests/test_properties.nim"

task testRelease, "Nim tests (release, contracts compiled away)":
  exec "nim c -r -d:release --path:src -o:build/test_arithmetic_rel tests/test_arithmetic.nim"
  exec "nim c -r -d:release --path:src -o:build/test_fixed_rel tests/test_fixed.nim"
  exec "nim c -r -d:release --path:src -o:build/test_float_rel tests/test_float.nim"
  exec "nim c -r -d:release --path:src -o:build/test_rational_rel tests/test_rational.nim"
  exec "nim c -r -d:release --path:src -o:build/test_interval_rel tests/test_interval.nim"
  exec "nim c -r -d:release --path:src -o:build/test_eft_rel tests/test_eft.nim"
  exec "nim c -r -d:release --path:src -o:build/test_roots_rel tests/test_roots.nim"
  exec "nim c -r -d:release --path:src -o:build/test_exponential_rel tests/test_exponential.nim"
  exec "nim c -r -d:release --path:src -o:build/test_trigonometry_rel tests/test_trigonometry.nim"
  exec "nim c -r -d:release --path:src -o:build/test_hyperbolic_rel tests/test_hyperbolic.nim"
  exec "nim c -r -d:release --path:src -o:build/test_special_rel tests/test_special.nim"
  exec "nim c -r -d:release --path:src -o:build/test_constants_rel tests/test_constants.nim"
  exec "nim c -r -d:release --path:src -o:build/test_reduction_rel tests/test_reduction.nim"
  exec "nim c -r -d:release --path:src -o:build/test_float_math_rel tests/test_float_math.nim"
  exec "nim c -r -d:release --path:src -o:build/test_rational_math_rel tests/test_rational_math.nim"
  exec "nim c -r -d:release --path:src -o:build/test_math_router_rel tests/test_math_router.nim"
  exec "nim c -r -d:release --path:src -o:build/test_conversions_rel tests/test_conversions.nim"
  exec "nim c -r -d:release --path:src -o:build/test_properties_rel tests/test_properties.nim"

task testSimd, "Nim tests with the opt-in SIMD backend (-d:simd)":
  exec "nim c -r -d:simd --path:src -o:build/test_arithmetic_simd tests/test_arithmetic_simd.nim"

# Its own task: the guards only exist under the flag, so the default suites
# compile them out and cannot cover them.
task testChecked, "Fixed-width overflow guards (-d:checkedArithmetic)":
  exec "nim c -r -d:checkedArithmetic --path:src -o:build/test_checked_arithmetic tests/test_checked_arithmetic.nim"

task testCi, "Nim tests (CI subset, debug)":
  exec "nimble test"

task testCiRelease, "Nim tests (CI subset, release)":
  exec "nimble testRelease"

task prop, "Randomized property suite (heavy: 2000 iters via -d:propIters)":
  exec "nim c -r -d:release -d:propIters=2000 --path:src -o:build/test_properties_prop tests/test_properties.nim"

task testAll, "debug + release + checked + C ABI + properties":
  exec "nimble test"
  exec "nimble testRelease"
  exec "nimble testChecked"
  exec "nimble ctest"
  exec "nimble prop"

task example, "Nim demo":
  exec "nim c -r --path:src -o:build/demo examples/demo.nim"

# Isolated benchmark harness (not in the default gate). Release build so the
# NimContracts `{.contractual.}` procs compile away and the timing reflects the
# shipped code path; the parity section compares BigFloat vs the float64 oracle.
task bench, "Perf + precision-parity benchmarks (release; not in the default gate)":
  exec "nim c -r -d:release --path:src -o:build/bench_arithmetic bench/bench_arithmetic.nim"
  exec "nim c -r -d:release --path:src -o:build/bench_transcendentals bench/bench_transcendentals.nim"

task benchReadme, "bench (+ benchSpeed if libmpfr/libgmp are available), splice into README.md":
  exec "nimble bench"
  let (_, pkgCode) = gorgeEx("pkg-config --exists mpfr gmp")
  if pkgCode == 0:
    # Build only (no `make run`), then execute directly so the captured file
    # is the C binary's own stdout, not nimble/make's build chatter too.
    exec "nimble clibStatic"
    exec "make -C bench bench_speed"
    exec "./bench/bench_speed > bench/.md_speed.txt"
  else:
    echo "benchReadme: no libmpfr/libgmp -- skipping the GMP/MPFR comparison"
  exec "nim c -r --path:src bench/export_readme.nim"

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

task clibStatic, "C static library":
  exec "nim c --app:staticlib --noMain --mm:arc --panics:off -d:release -o:" & staticLib &
       " src/UniMath/c_api.nim"

task clibMsvc, "C static library, MSVC ABI (Windows Python extension)":
  # CPython on Windows is MSVC-built and cannot link MinGW output.
  exec "nim c --cc:vcc --app:staticlib --noMain --mm:arc --panics:off -d:release" &
       " -o:UniMath.lib src/UniMath/c_api.nim"

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
  exec "nimble clibStatic"
  exec makeExe & " -C tests/c" & winMakeVars("test_unimath")

task cexample, "C demo":
  exec "nimble clibStatic"
  exec makeExe & " -C examples/c" & winMakeVars("demo")

# Head-to-head speed vs the native GMP/MPFR oracles at matching precision.
# Linux/macOS only (needs libmpfr/libgmp via pkg-config); NOT in the default
# gate — run `nimble benchSpeed` explicitly. Builds the static lib, compiles
# bench/bench_speed.c against it + libmpfr + libgmp, and runs the comparison.
task benchSpeed, "UniMath-vs-GMP/MPFR speed benchmark (needs libmpfr/libgmp; not in the default gate)":
  exec "nimble clibStatic"
  exec makeExe & " -C bench"

# Native oracles: independent MPFR/GMP references for the exact-type and
# transcendental tests. Linux/macOS only (need libmpfr/libgmp via pkg-config);
# NOT in the default gate — run `nimble testOracle` explicitly. The C binaries
# are gitignored; lint does not scan oracles/ (only src/tests/examples/book).
task buildOracles, "Build the MPFR and GMP C oracles (needs libmpfr/libgmp)":
  exec "cc -O2 -std=c11 -o oracles/mpfr_oracle oracles/mpfr_oracle.c " &
       "$(pkg-config --cflags --libs mpfr gmp)"
  exec "cc -O2 -std=c11 -o oracles/gmp_oracle oracles/gmp_oracle.c " &
       "$(pkg-config --cflags --libs gmp)"

task testOracle, "Oracle tests — GMP/MPFR/EFT (needs libmpfr/libgmp; not in the default gate)":
  exec "nimble buildOracles"
  exec "nim c -r --path:. --hints:off -o:build/test_oracle tests/test_oracle_smoke.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_gmp_oracle tests/test_gmp_oracle.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_fixed_oracle tests/test_fixed_oracle.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_bigfloat_oracle tests/test_bigfloat_oracle.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_float_math_oracle tests/test_float_math_oracle.nim"
  exec "nim c -r --path:src --path:. --hints:off -o:build/test_rational_oracle tests/test_rational_oracle.nim"

# The Windows launcher is `python`; `python3` only exists elsewhere.
const pyExe = when defined(windows): "python" else: "python3"

task pyDeps, "Install Python build deps (setuptools, Cython, pytest) if missing":
  exec pyExe & " -m pip install --break-system-packages --quiet setuptools wheel \"Cython>=3.0.0\" pytest"

# The extension links the vcc static lib on Windows, the shared lib elsewhere.
task pyLib, "Build the library the Python extension links against":
  when defined(windows):
    exec "nimble clibMsvc"
  else:
    exec "nimble clib"

# `withDir`, not `cd py && ...`: nimble's exec runs no shell on Windows.
task buildCython, "Cython extension in-place":
  exec "nimble pyLib"
  exec "nimble pyDeps"
  withDir "py":
    exec pyExe & " setup.py build_ext --inplace"

task pyTest, "Cython extension + pytest":
  exec "nimble buildCython"
  withDir "py":
    exec pyExe & " -m pytest -q"

task pyWheel, "wheel":
  exec "nimble pyLib"
  exec "nimble pyDeps"
  withDir "py":
    exec pyExe & " setup.py bdist_wheel"

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
