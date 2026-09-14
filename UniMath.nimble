# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# UniMath — a multi-precision numeric library.

version = "1.1.0"
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

# From the URL with a tag, not from the registry: the nimble registry lags
# upstream, and `nimble install nimibook` resolves 0.3.1, whose themes.nim does
# not compile against nimib 0.4.x. The theme is pinned for a different reason --
# several installs of one version is a resolution nimble cannot make, and it
# picks between them in silence.
const bookDeps = [
  "https://github.com/pietroppeter/nimib#v0.4.1",
  "https://github.com/pietroppeter/nimibook#v0.4.0",
  "https://github.com/lituus-lab/lituus-theme#v0.2.0",
]
taskRequires "docsDeps", bookDeps[0], bookDeps[1], bookDeps[2]
taskRequires "book", bookDeps[0], bookDeps[1], bookDeps[2]
taskRequires "docs", bookDeps[0], bookDeps[1], bookDeps[2]

task docsDeps, "Install the docs toolchain (nimib + nimibook + theme)":
  # This task's own `taskRequires` above is what fetches them: nimble resolves
  # and installs a task's requirements before running its body.
  echo "nimib, nimibook and lituus-theme installed."
  done "docsDeps"

task bookInit, "Scaffold a chapter added to the table of contents":
  withDir "book":
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim init"
  done "bookInit"

task book, "Build the multi-chapter book (needs nimib + nimibook)":
  # The chapters compile and run their own code, so a drift in any of them
  # fails the build. Run from book/, because nimibook reads the nimib.toml of
  # the directory it starts in.
  withDir "book":
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim clean"
    # `init` before `build`, on every run: it is what creates `__site/assets`,
    # which is not tracked, so a fresh clone has none and every page ships
    # referencing a stylesheet and a script that are not there.
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim init"
    exec "nim c -r --hints:off -o:../build/nbook nbook.nim build"
  done "book"

task docs, "API reference + book into pages/ — what CI publishes":
  rmDir "pages"
  exec gate("book")
  # The book *is* the site: its pages link to `assets/` and to each other as
  # siblings, so it is copied whole to the root rather than nested.
  cpDir "book/__site", "pages"
  # book.json is nimibook's build state -- no page fetches it -- and it carries
  # the absolute path of the machine that built it. It does not get published.
  rmFile "pages/book.json"
  # The generated reference sits beside the book, not inside it.
  exec "nim doc --index:on --outdir:pages/api --project --hints:off src/UniMath.nim"
  # ...and wears the same theme. `nim doc` has no stylesheet option, so the
  # palette is appended to the one it just wrote.
  exec "nim c -r --hints:off --outdir:build tools/theme_api.nim " &
       "pages/api/nimdoc.out.css"
  done "docs"

# The suite `test`, `testRelease` and `coverage` all run. Held once: the
# coverage task used to name a single file of its own, and reported the
# 82% that one file reached as though it were the library's.
const unitTests = [
  "tests/test_primitives.nim",
  "tests/test_native_float.nim",
  "tests/test_arithmetic.nim",
  "tests/test_fixed.nim",
  "tests/test_float.nim",
  "tests/test_rational.nim",
  "tests/test_interval.nim",
  "tests/test_complex.nim",
  "tests/test_eft.nim",
  "tests/test_roots.nim",
  "tests/test_exponential.nim",
  "tests/test_trigonometry.nim",
  "tests/test_hyperbolic.nim",
  "tests/test_special.nim",
  "tests/test_constants.nim",
  "tests/test_reduction.nim",
  "tests/test_float_math.nim",
  "tests/test_float_math_precision.nim",
  "tests/test_rational_math.nim",
  "tests/test_complex_math.nim",
  "tests/test_math_router.nim",
  "tests/test_conversions.nim",
  "tests/test_version.nim",
  "tests/test_properties.nim",
]

task test, "Nim tests (debug, contracts active)":
  for t in unitTests:
    let name = t[6 .. ^5]
    exec "nim c -r --path:src -o:build/" & name & " " & t
  done "test"

task testRelease, "Nim tests (release, contracts compiled away)":
  for t in unitTests:
    let name = t[6 .. ^5]
    exec "nim c -r -d:release --path:src -o:build/" & name & "_rel " & t
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
  exec "nim c --app:lib -d:noAutoInit --noMain --mm:arc --panics:off -d:release -o:" & sharedLib & macArgs &
       " src/UniMath/c_api.nim"
  done "clib"

task clibStatic, "C static library":
  exec "nim c --app:staticlib -d:noAutoInit --noMain --mm:arc --panics:off -d:release -o:" & staticLib &
       " src/UniMath/c_api.nim"
  done "clibStatic"

task clibMsvc, "C static library, MSVC ABI (Windows Python extension)":
  # CPython on Windows is MSVC-built and cannot link MinGW output.
  exec "nim c --cc:vcc --app:staticlib -d:noAutoInit --noMain --mm:arc --panics:off -d:release" &
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
  # Ubuntu ships a setuptools that predates PEP 639 and cannot parse the SPDX
  # licence pyproject.toml declares. pip refuses to uninstall a distro- or
  # brew-managed package, so install over it rather than --upgrade it.
  # packaging comes with it: setuptools 77 reads packaging.licenses, which the
  # distro's older copy does not have, and it shadows the vendored one.
  exec pyExe & " -m pip install --break-system-packages --quiet --ignore-installed \"setuptools>=77\" \"packaging>=24.2\""
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
  # codegen.
  # `mismatch` is the one suppression, and it is not optional: lcov 2.x checks
  # its own end line for a function against gcov's, and Nim's generated
  # destructors disagree -- a closure environment, a seq, NimContracts'
  # PostConditionDefect. Removing one only advances lcov to the next, so there
  # is no source-level fix. Every other lcov error still fails the build.
  let cache = "build/covcache"
  rmDir cache
  rmDir "coverage"
  # Every unit test, each with its own nimcache: one shared cache would let a
  # later compilation overwrite the .gcno of an earlier one, and the modules
  # only that earlier test reaches would vanish from the report rather than
  # show as uncovered.
  var index = 0
  for t in unitTests:
    exec "nim c --path:src --nimcache:" & cache & "/" & $index &
         " --debugger:native --passC:--coverage --passL:--coverage" &
         " -o:build/cov/" & t[6 .. ^5] & " " & t
    inc index
  for t in unitTests:
    exec "./build/cov/" & t[6 .. ^5]
  exec "lcov --capture --directory " & cache & " --base-directory ." &
       " --include \"*/src/UniMath/*\" --output-file build/nim.info --quiet" &
       " --ignore-errors mismatch"
  # The C ABI answers to no Nim test: `ctest` reaches it through a C consumer
  # linking the static library, so its lines were absent from the report rather
  # than shown as uncovered -- 1411 of them, the surface that must clamp instead
  # of raising. Built -d:release like the shipped archive, because that is where
  # the contracts are compiled away and the clamps are what remains.
  let capiCache = "build/capicov"
  rmDir capiCache
  exec "nim c --app:staticlib -d:noAutoInit --noMain --mm:arc --panics:off" &
       " -d:release --debugger:native --passC:--coverage --passL:--coverage" &
       " --nimcache:" & capiCache & " -o:build/libUniMath_cov.a src/UniMath/c_api.nim"
  # -lm as tests/c/Makefile passes it: macOS folds libm into libSystem and links
  # without it, Linux does not and fails on log/atan2 from complex_math.
  exec "cc -Iinclude -O2 -Wall -Wextra -std=c11 --coverage" &
       " -o build/test_capi_cov tests/c/test_unimath.c build/libUniMath_cov.a -lm"
  exec "./build/test_capi_cov"
  exec "lcov --capture --directory " & capiCache & " --base-directory ." &
       " --include \"*/src/UniMath/*\" --output-file build/capi.info --quiet" &
       " --ignore-errors mismatch,unsupported"
  # One report, both harnesses: a line the Nim suite misses and the C consumer
  # reaches counts as covered, which is the truth about the library.
  exec "lcov -a build/nim.info -a build/capi.info --output-file lcov.info" &
       " --quiet --ignore-errors mismatch,unsupported"
  # gcov can attribute a final generated expression to EOF + 1, and that one
  # artefact answers to two names: lcov 2.0, the version ubuntu-latest installs,
  # calls it `unmapped` and rejects `range` as a category outright, while 2.5
  # calls it `range` and can filter those lines away. Ask which one is there
  # rather than assume; both were measured.
  let genhtmlRange =
    if gorgeEx("genhtml --version").output.contains("LCOV version 2.0"):
      " --ignore-errors unmapped"
    else: " --filter range --ignore-errors range"
  exec "genhtml lcov.info" & genhtmlRange &
       " --output-directory coverage --legend --quiet"
  exec "lcov --summary lcov.info"
  done "coverage"
