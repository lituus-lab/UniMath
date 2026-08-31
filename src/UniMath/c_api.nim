# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## C ABI for UniMath. Built --app:staticlib/--app:lib --noMain --mm:arc -d:release.
## Keep in sync with include/UniMath.h; tests/c links the header against this lib.
##
## Handle-based: BigInt values are pinned `ref BigInt` objects owned by the C
## host until `unimath_bigint_destroy`. The C host MUST call `unimath_init()`
## once before any other entry point — handles persist Nim heap objects across
## the boundary, and the Nim/ARC runtime is not lazily brought up under
## `--app:lib` (only the C `main` is suppressed; `NimMain` still bootstraps the
## allocator and module initialisers). Never raises: returns NULL / 0 / -1 on
## bad input or domain errors (div by zero), clamps out-of-range results.
##
## Predicates return `cint` 1/0, never Nim `bool`: `bool` is one byte, so a C
## caller reading the declared `int` picks up whatever the ABI left in the
## upper bytes of the return register — true-looking garbage for a false result.
import std/[strutils, math]
import ./arithmetic
import ./fixed
import ./float
import ./rational
import ./interval
import ./roots
import ./exponential
import ./trigonometry
import ./hyperbolic
import ./special
import ./special/gamma
import ./special/beta as beta_functions
import ./constants
import ./reduction
import ./float_math
import ./rational_math
import ./math_router
import ./conversions
import ./native_float
import ./complex
import ./complex_math

const UniMathVersionC: cstring = "1.1.0"

# ------------------------------------------------------------------------------
# Internal helpers (NOT exported): pinned BigInt handle, decimal parse, clamp.
# ------------------------------------------------------------------------------

type AbiBigInt = ref BigInt

proc pin(b: BigInt): pointer =
  ## Box a BigInt in a pinned ref the C host owns until `*_destroy`.
  let r = new(AbiBigInt)
  r[] = b
  GC_ref(r) # pin beyond ARC; the C host now owns the reference
  cast[pointer](r)

proc bigOf(h: pointer): BigInt {.inline.} =
  if h == nil: return initBigInt(0)
  cast[AbiBigInt](h)[]

proc unrefBigInt(h: pointer) {.inline.} =
  if h != nil: GC_unref(cast[AbiBigInt](h))

func initBigIntFromDecimal(s: string): BigInt =
  ## Strict base-10 parse (optional leading +/-). Raises `ValueError` on no
  ## digits or trailing non-digit characters — the inverse of `toDecimal` must
  ## round-trip, and the header promises NULL on malformed input, so "12abc"
  ## must reject, not silently yield 12.
  var i = 0
  var neg = false
  if i < s.len and s[i] == '-': neg = true; inc i
  elif i < s.len and s[i] == '+': inc i
  result = initBigInt(0)
  var seen = false
  while i < s.len and s[i].isDigit:
    result = result * initBigInt(10) + initBigInt(ord(s[i]) - ord('0'))
    inc i
    seen = true
  if not seen: raise newException(ValueError, "no decimal digits")
  if i != s.len:
    raise newException(ValueError,
      "trailing non-digit characters in decimal string")
  if neg: result = -result

proc clampToInt64(b: BigInt): int64 =
  ## Exact-BigInt result clamped to the int64 range (no silent overflow, no
  ## raise across the boundary).
  if b < initBigInt(low(int64)): return low(int64)
  if b > initBigInt(high(int64)): return high(int64)
  toInt64(b)

type AbiBigFloat = ref BigFloat

proc pinFloat(b: BigFloat): pointer =
  ## Box a BigFloat in a pinned ref the C host owns until `*_destroy`.
  let r = new(AbiBigFloat)
  r[] = b
  GC_ref(r)
  cast[pointer](r)

proc bfOf(h: pointer): BigFloat {.inline.} =
  if h == nil: return BigFloat(mantissa: initBigUInt(0'u64))
  cast[AbiBigFloat](h)[]

proc unrefBigFloat(h: pointer) {.inline.} =
  if h != nil: GC_unref(cast[AbiBigFloat](h))

type AbiRational = ref Rational[BigInt]

proc pinRational(r: Rational[BigInt]): pointer =
  ## Box a `Rational[BigInt]` in a pinned ref the C host owns until `*_destroy`.
  let s = new(AbiRational)
  s[] = r
  GC_ref(s)
  cast[pointer](s)

proc ratOf(h: pointer): Rational[BigInt] {.inline.} =
  if h == nil: return initRational(initBigInt(0), initBigInt(1))
  cast[AbiRational](h)[]

proc unrefRational(h: pointer) {.inline.} =
  if h != nil: GC_unref(cast[AbiRational](h))

# Fixed transcendentals operate on raw Q32.32 `int64` data (the `data` field of
# `Fixed[int64, 32]`); this wraps the raw word back into the typed value.
proc fxOf(q: int64): Fixed[int64, 32] {.inline.} =
  initFixed[int64, 32](q)

# Interval passes by value (two doubles), not by handle.
type
  IntervalC {.bycopy, exportc: "unimath_interval".} = object
    lo*: float64
    hi*: float64
  F64PairC {.bycopy, exportc: "unimath_f64_pair".} = object
    first*: float64
    second*: float64

# Complex[float64] does the same: two doubles, no handle, so nothing to
# destroy. A BigFloat-backed complex would need the pinned-ref treatment.
type
  ComplexC {.bycopy, exportc: "unimath_complex".} = object
    re*: float64
    im*: float64

proc cxOf(z: ComplexC): Complex[float64] {.inline.} =
  complex(z.re, z.im)

proc cxTo(z: Complex[float64]): ComplexC {.inline.} =
  ComplexC(re: z.re, im: z.im)

const NaNComplexC = ComplexC(re: NaN, im: NaN)

# A Fixed-backed complex is two raw Q-format words, by value like the Fixed
# scalars themselves.
type
  ComplexFixedC {.bycopy, exportc: "unimath_complex_fixed".} = object
    re*: int64
    im*: int64

# BigFloat- and Rational-backed complexes carry heap components, so they follow
# the handle discipline of their scalars: a pinned ref the C host owns until
# `*_destroy`.
type
  AbiComplexBigFloat = ref Complex[BigFloat]
  AbiComplexRational = ref Complex[Rational[BigInt]]

proc pinCxFloat(z: Complex[BigFloat]): pointer =
  let r = new(AbiComplexBigFloat)
  r[] = z
  GC_ref(r)
  cast[pointer](r)

proc cxfOf(h: pointer): Complex[BigFloat] {.inline.} =
  if h == nil: return complex(bfOf(nil), bfOf(nil))
  cast[AbiComplexBigFloat](h)[]

proc unrefCxFloat(h: pointer) {.inline.} =
  if h != nil: GC_unref(cast[AbiComplexBigFloat](h))

proc pinCxRat(z: Complex[Rational[BigInt]]): pointer =
  let r = new(AbiComplexRational)
  r[] = z
  GC_ref(r)
  cast[pointer](r)

proc cxrOf(h: pointer): Complex[Rational[BigInt]] {.inline.} =
  if h == nil:
    let z = initRational(initBigInt(0), initBigInt(1))
    return complex(z, z)
  cast[AbiComplexRational](h)[]

proc unrefCxRat(h: pointer) {.inline.} =
  if h != nil: GC_unref(cast[AbiComplexRational](h))

# Internal init-once flag. Declared OUTSIDE the `{.push exportc, cdecl, dynlib.}`
# block so it is NOT exported as an undocumented C symbol (a writable `bool`
# would let a C host bypass `unimath_init()` and trip a handle-NULL cascade).
var gInited: bool

# `sqrt` witness for `erfTaylor`, declared OUTSIDE the `{.push cdecl.}` block so
# its calling convention is the default `nimcall` that `erfTaylor`'s parameter
# expects (a `cdecl` proc cannot be passed where a `nimcall`/closure is wanted).
proc sqrtF64Abi(v: float64): float64 {.noSideEffect.} = math.sqrt(v)
proc expF64Abi(v: float64): float64 {.noSideEffect.} = math.exp(v)


# A shared library runs NimMain from DllMain (Windows) or an ELF constructor;
# a static one has neither, so nothing initializes the Nim runtime. The first
# entry point then enters Nim code whose globals were never set up and the
# process faults. The static-library tasks pass -d:staticNoAutoInit; shared
# builds must not, or NimMain runs twice.
when defined(staticNoAutoInit):
  # A once primitive, not a plain flag: two threads reaching an entry point
  # together would both see the flag unset, both call NimMain, and the second
  # would enter Nim code the first had not finished initializing. The platform
  # primitives block the losers until the winner returns, which a flag cannot.
  #
  # C statics, not Nim globals: module initialization would reset a Nim one and
  # NimMain would run again. NimMain is declared here too — the generated
  # prototype comes after this section.
  {.emit: """/*VARSECTION*/
void NimMain(void);
#ifdef _WIN32
#  include <windows.h>
static INIT_ONCE unimath_runtime_once = INIT_ONCE_STATIC_INIT;
static BOOL CALLBACK unimath_runtime_init(PINIT_ONCE o, PVOID p, PVOID *c) {
  (void)o; (void)p; (void)c; NimMain(); return TRUE;
}
static void unimath_runtime_ensure(void) {
  InitOnceExecuteOnce(&unimath_runtime_once, unimath_runtime_init, NULL, NULL);
}
#else
#  include <pthread.h>
static pthread_once_t unimath_runtime_once = PTHREAD_ONCE_INIT;
static void unimath_runtime_init(void) { NimMain(); }
static void unimath_runtime_ensure(void) {
  pthread_once(&unimath_runtime_once, unimath_runtime_init);
}
#endif
""".}
  template ensureRuntime() =
    {.emit: "  unimath_runtime_ensure();".}
else:
  template ensureRuntime() = discard


{.push exportc, cdecl, dynlib.}

# ------------------------------------------------------------------------------
# Version & lifecycle.
# ------------------------------------------------------------------------------

proc unimath_version(): cstring =
  ## Library version (e.g. "1.1.0"); static, do not free.
  ensureRuntime()
  UniMathVersionC

proc NimMain() {.importc, cdecl.}

proc unimath_init(): cint =
  ## Bring up the Nim/ARC runtime. Call once before any other entry point.
  ## Returns 1. Idempotent from a single thread only: `gInited` is a plain
  ## `bool`, so two threads racing the first call can both run `NimMain`.
  ##
  ## The ABI as a whole is single-threaded -- the host must serialise every
  ## call. The handle procs adjust ARC reference counts through `GC_ref` /
  ## `GC_unref`, and those counts are non-atomic in this build, so sharing one
  ## handle across threads corrupts them and either leaks or frees early.
  ## Stated in `include/UniMath.h` alongside the init requirement.
  ensureRuntime()
  if not gInited:
    NimMain()
    gInited = true
  cint(1)

proc unimath_cleanup() =
  ## No-op (matches `unimath_init`); handles are freed per-call by `*_destroy`.
  ensureRuntime()
  discard

proc unimath_get_error_string(error_code: cint): cstring =
  ensureRuntime()
  case int(error_code)
  of 0: "Success"
  of 1: "Division by zero"
  of 2: "Overflow"
  of 3: "Invalid argument"
  of 4: "Out of memory"
  else: "Unknown error"

# ------------------------------------------------------------------------------
# Native float64 mathematics — value-only, preserving host libm semantics.
# ------------------------------------------------------------------------------

proc unimath_f64_sqrt(x: float64): float64 =
  ensureRuntime()
  native_float.sqrt(x)
proc unimath_f64_cbrt(x: float64): float64 =
  ensureRuntime()
  native_float.cbrt(x)
proc unimath_f64_ln(x: float64): float64 =
  ensureRuntime()
  native_float.ln(x)
proc unimath_f64_log(x, base: float64): float64 =
  ensureRuntime()
  native_float.log(x, base)
proc unimath_f64_log2(x: float64): float64 =
  ensureRuntime()
  native_float.log2(x)
proc unimath_f64_log10(x: float64): float64 =
  ensureRuntime()
  native_float.log10(x)
proc unimath_f64_log1p(x: float64): float64 =
  ensureRuntime()
  native_float.log1p(x)
proc unimath_f64_exp(x: float64): float64 =
  ensureRuntime()
  native_float.exp(x)
proc unimath_f64_expm1(x: float64): float64 =
  ensureRuntime()
  native_float.expm1(x)
proc unimath_f64_pow(base, exponent: float64): float64 =
  ensureRuntime()
  native_float.pow(base, exponent)
proc unimath_f64_sin(x: float64): float64 =
  ensureRuntime()
  native_float.sin(x)
proc unimath_f64_cos(x: float64): float64 =
  ensureRuntime()
  native_float.cos(x)
proc unimath_f64_tan(x: float64): float64 =
  ensureRuntime()
  native_float.tan(x)
proc unimath_f64_sin_cos(x: float64): F64PairC =
  ensureRuntime()
  let pair = native_float.sinCos(x)
  F64PairC(first: pair.sin, second: pair.cos)
proc unimath_f64_atan2(y, x: float64): float64 =
  ensureRuntime()
  native_float.arctan2(y, x)
proc unimath_f64_arcsin(x: float64): float64 =
  ensureRuntime()
  native_float.arcsin(x)
proc unimath_f64_arccos(x: float64): float64 =
  ensureRuntime()
  native_float.arccos(x)
proc unimath_f64_arctan(x: float64): float64 =
  ensureRuntime()
  native_float.arctan(x)
proc unimath_f64_sinh(x: float64): float64 =
  ensureRuntime()
  native_float.sinh(x)
proc unimath_f64_cosh(x: float64): float64 =
  ensureRuntime()
  native_float.cosh(x)
proc unimath_f64_tanh(x: float64): float64 =
  ensureRuntime()
  native_float.tanh(x)
proc unimath_f64_arcsinh(x: float64): float64 =
  ensureRuntime()
  native_float.arcsinh(x)
proc unimath_f64_arccosh(x: float64): float64 =
  ensureRuntime()
  native_float.arccosh(x)
proc unimath_f64_arctanh(x: float64): float64 =
  ensureRuntime()
  native_float.arctanh(x)
proc unimath_f64_hypot(x, y: float64): float64 =
  ensureRuntime()
  native_float.hypot(x, y)
proc unimath_f64_erf(x: float64): float64 =
  ensureRuntime()
  native_float.erf(x)
proc unimath_f64_erfc(x: float64): float64 =
  ensureRuntime()
  native_float.erfc(x)
proc unimath_f64_gamma(x: float64): float64 =
  ensureRuntime()
  native_float.gamma(x)
proc unimath_f64_lgamma(x: float64): float64 =
  ensureRuntime()
  native_float.lgamma(x)
proc unimath_f64_log_beta(a, b: float64): float64 =
  ensureRuntime()
  if classify(a) in {fcNan, fcInf, fcNegInf} or
      classify(b) in {fcNan, fcInf, fcNegInf} or a <= 0.0 or b <= 0.0 or
      classify(a + b) in {fcNan, fcInf, fcNegInf}:
    return NaN
  beta_functions.logBeta(a, b)
proc unimath_f64_beta(a, b: float64): float64 =
  ensureRuntime()
  if classify(a) in {fcNan, fcInf, fcNegInf} or
      classify(b) in {fcNan, fcInf, fcNegInf} or a <= 0.0 or b <= 0.0 or
      classify(a + b) in {fcNan, fcInf, fcNegInf}:
    return NaN
  beta_functions.beta(a, b)
proc unimath_f64_regularized_incomplete_beta(x, a, b: float64): float64 =
  ensureRuntime()
  if classify(x) in {fcNan, fcInf, fcNegInf} or x < 0.0 or x > 1.0 or
      classify(a) in {fcNan, fcInf, fcNegInf} or
      classify(b) in {fcNan, fcInf, fcNegInf} or a <= 0.0 or b <= 0.0 or
      classify(a) == fcSubnormal or classify(b) == fcSubnormal or
      classify(a + b) in {fcNan, fcInf, fcNegInf} or
      (a != 1.0 and b != 1.0 and
        a + b > MaximumRegularizedBetaShapeSum):
    return NaN
  try:
    beta_functions.regularizedIncompleteBeta(x, a, b)
  except ValueError:
    NaN
proc unimath_f64_floor(x: float64): float64 =
  ensureRuntime()
  native_float.floor(x)
proc unimath_f64_ceil(x: float64): float64 =
  ensureRuntime()
  native_float.ceil(x)
proc unimath_f64_trunc(x: float64): float64 =
  ensureRuntime()
  native_float.trunc(x)
proc unimath_f64_round(x: float64): float64 =
  ensureRuntime()
  native_float.round(x)
proc unimath_f64_round_places(x: float64; places: cint): float64 =
  ensureRuntime()
  native_float.round(x, int(places))
proc unimath_f64_copy_sign(x, sign: float64): float64 =
  ensureRuntime()
  native_float.copySign(x, sign)
proc unimath_f64_next_after(x, direction: float64): float64 =
  ensureRuntime()
  nextafterF64(x, direction)
proc unimath_f64_deg_to_rad(x: float64): float64 =
  ensureRuntime()
  native_float.degToRad(x)
proc unimath_f64_rad_to_deg(x: float64): float64 =
  ensureRuntime()
  native_float.radToDeg(x)
proc unimath_f64_split_decimal(x: float64): F64PairC =
  ensureRuntime()
  let parts = native_float.splitDecimal(x)
  F64PairC(first: parts.intpart, second: parts.floatpart)
proc unimath_f64_frexp(x: float64; exponent: ptr cint): float64 =
  ensureRuntime()
  let parts = native_float.frexp(x)
  if exponent != nil: exponent[] = cint(parts.exp)
  parts.frac
proc unimath_f64_signbit(x: float64): cint =
  ensureRuntime()
  cint(native_float.signbit(x))
proc unimath_f64_classify(x: float64): cint =
  ensureRuntime()
  case native_float.classify(x)
  of fcNormal: 0
  of fcSubnormal: 1
  of fcZero: 2
  of fcNegZero: 3
  of fcNan: 4
  of fcInf: 5
  of fcNegInf: 6
proc unimath_f64_almost_equal(x, y: float64; ulps: cint): cint =
  ensureRuntime()
  if ulps < 0: return 0
  cint(native_float.almostEqual(x, y, Natural(ulps)))

# ------------------------------------------------------------------------------
# BigInt — handle = pinned ref BigInt.
# ------------------------------------------------------------------------------

proc unimath_bigint_from_i64(v: int64): pointer =
  ensureRuntime()
  pin(initBigInt(v))

proc unimath_bigint_from_decimal(s: cstring): pointer =
  ## Parse base-10. NULL on nil input or a malformed string (no digits, or
  ## trailing non-digit characters — strict parse).
  ensureRuntime()
  if s == nil: return nil
  try: pin(initBigIntFromDecimal($s))
  except ValueError: nil

proc unimath_bigint_to_decimal(h: pointer; buf: ptr char; size: csize_t): cint =
  ## Write the NUL-terminated decimal into `buf`. Returns chars written
  ## (excluding NUL), the required character count when the buffer is too
  ## small, or -1 on a nil handle / nil buffer. A zero-sized non-nil buffer is
  ## a size query. Nothing is written unless the buffer also holds the NUL.
  ensureRuntime()
  if h == nil or buf == nil: return cint(-1)
  let s = toDecimal(bigOf(h))
  if csize_t(s.len) >= size: return cint(s.len)
  let dst = cast[ptr UncheckedArray[char]](buf)
  copyMem(addr dst[0], unsafeAddr s[0], s.len)
  dst[s.len] = '\0'
  cint(s.len)

proc unimath_bigint_add(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pin(bigOf(a) + bigOf(b))

proc unimath_bigint_sub(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pin(bigOf(a) - bigOf(b))

proc unimath_bigint_mul(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pin(bigOf(a) * bigOf(b))

proc unimath_bigint_mul_into(acc, k: pointer): pointer =
  ## Consume the accumulator handle and return its replacement. The owned box
  ## is reused; a distinct single-limb multiplier also reuses its limb buffer.
  ensureRuntime()
  if acc == nil: return nil
  if k == nil:
    unrefBigInt(acc)
    return nil
  let target = cast[AbiBigInt](acc)
  if acc == k:
    target[] = target[] * target[]
    return acc
  let factor = bigOf(k)
  if factor.isZero or target[].isZero:
    target[] = initBigInt(0)
  elif factor.mag.limbs.len == 1:
    let multiplier = factor.mag.limbs[0]
    var carry = ZeroLimb
    for i in 0 ..< target[].mag.limbs.len:
      target[].mag.limbs[i] = mulAdd(target[].mag.limbs[i], multiplier,
        ZeroLimb, carry)
    if carry != ZeroLimb:
      target[].mag.limbs.add(carry)
    target[].isNegative = target[].isNegative != factor.isNegative
  else:
    target[] = target[] * factor
  acc

proc unimath_bigint_div(a, b: pointer): pointer =
  ## Truncated-toward-zero quotient (matches the signed `div`). NULL on
  ## division by zero or a nil handle.
  ensureRuntime()
  if a == nil or b == nil: return nil
  if isZero(bigOf(b)): return nil
  pin(bigOf(a) div bigOf(b))

proc unimath_bigint_mod(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  if isZero(bigOf(b)): return nil
  pin(bigOf(a) mod bigOf(b))

proc unimath_bigint_neg(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pin(-bigOf(a))

proc unimath_bigint_abs(a: pointer): pointer =
  ## Magnitude as a non-negative BigInt.
  ensureRuntime()
  if a == nil: return nil
  pin(initBigInt(abs(bigOf(a)), false))

proc unimath_bigint_cmp(a, b: pointer): cint =
  ## -1 / 0 / 1. Returns 0 if either handle is nil.
  ensureRuntime()
  if a == nil or b == nil: return cint(0)
  cint(cmp(bigOf(a), bigOf(b)))

proc unimath_bigint_to_i64(h: pointer; out_ok: ptr cint): int64 =
  ## Best-effort int64, clamped to the int64 range. If `out_ok` is non-NULL,
  ## `*out_ok` is false when the value was out of range (clamped) or the handle
  ## is nil.
  ensureRuntime()
  if h == nil:
    if out_ok != nil: out_ok[] = cint(false)
    return 0
  let b = bigOf(h)
  let inRange = b >= initBigInt(low(int64)) and b <= initBigInt(high(int64))
  if out_ok != nil: out_ok[] = cint(inRange)
  clampToInt64(b)

proc unimath_bigint_to_u64(h: pointer; out_ok: ptr cint): uint64 =
  ## Best-effort uint64, clamped to `[0, UINT64_MAX]`. If `out_ok` is non-NULL,
  ## `*out_ok` is false when the value was negative or out of range (clamped)
  ## or the handle is nil.
  ensureRuntime()
  if h == nil:
    if out_ok != nil: out_ok[] = cint(false)
    return 0
  let b = bigOf(h)
  if b.isNegative:
    if out_ok != nil: out_ok[] = cint(false)
    return 0'u64
  if b.mag.limbs.len > 1:
    if out_ok != nil: out_ok[] = cint(false)
    return high(uint64)
  if out_ok != nil: out_ok[] = cint(true)
  toUInt64(b)

proc unimath_bigint_shl(a: pointer; k: cint): pointer =
  ## `a << k` (sign preserved). NULL on a nil handle or negative `k`.
  ensureRuntime()
  if a == nil or k < 0: return nil
  pin(bigOf(a) shl Natural(int(k)))

proc unimath_bigint_shr(a: pointer; k: cint): pointer =
  ## Arithmetic shift right (floor division by `2^k`, sign-extending). NULL on
  ## a nil handle or negative `k`.
  ensureRuntime()
  if a == nil or k < 0: return nil
  pin(bigOf(a) shr Natural(int(k)))

proc unimath_bigint_destroy(h: pointer) =
  ensureRuntime()
  unrefBigInt(h)

# ------------------------------------------------------------------------------
# A raw Q-format value in an int64 carries at most 63 fractional bits. Without
# an upper bound the parameter drives either a multi-hundred-megabyte BigInt
# shift or an undefined machine shift width, so every entry point taking it
# rejects out-of-range values the same way it rejects a negative one.
const MaxFracBits = 63

# Fixed — raw int64 Q-format. `frac_bits` is the fractional width. Never
# raises: out-of-range results clamp to the int64 range (exact BigInt
# intermediate, no float64 detour); division by zero returns 0. add/sub are
# scale-invariant; mul/div take `frac_bits`.
# ------------------------------------------------------------------------------

proc unimath_fixed_from_int(val: int64; frac_bits: cint): int64 =
  ## `val << frac_bits` as a raw Q-format value, clamped to int64. A negative
  ## `frac_bits` is malformed (wraps `Natural` to ~2^64); return 0, matching
  ## `unimath_fixed_from_rational`, so the ABI never raises.
  ensureRuntime()
  if frac_bits < 0 or frac_bits > MaxFracBits: return 0
  clampToInt64(initBigInt(val) shl Natural(int(frac_bits)))

proc unimath_fixed_to_int(q: int64; frac_bits: cint): int64 =
  ## Integer part `q >> frac_bits` (arithmetic shift). A negative `frac_bits`
  ## would reverse the shift; return 0 (never raises).
  ensureRuntime()
  if frac_bits < 0 or frac_bits > MaxFracBits: return 0
  ashr(q, int(frac_bits))

proc unimath_fixed_add(a, b: int64): int64 =
  ## Same-scale sum, clamped to int64.
  ensureRuntime()
  clampToInt64(initBigInt(a) + initBigInt(b))

proc unimath_fixed_sub(a, b: int64): int64 =
  ## Same-scale difference, clamped to int64.
  ensureRuntime()
  clampToInt64(initBigInt(a) - initBigInt(b))

proc unimath_fixed_mul(a, b: int64; frac_bits: cint): int64 =
  ## `(a * b) >> frac_bits` (arithmetic shift), clamped to int64. A negative
  ## `frac_bits` is malformed; return 0 (never raises).
  ensureRuntime()
  if frac_bits < 0 or frac_bits > MaxFracBits: return 0
  clampToInt64((initBigInt(a) * initBigInt(b)) shr Natural(int(frac_bits)))

proc unimath_fixed_div(a, b: int64; frac_bits: cint): int64 =
  ## `(a << frac_bits) / b` (truncated toward zero), clamped to int64. Returns
  ## 0 on division by zero or a negative `frac_bits` (never raises).
  ensureRuntime()
  if b == 0: return 0
  if frac_bits < 0: return 0
  clampToInt64((initBigInt(a) shl Natural(int(frac_bits))) div initBigInt(b))

proc unimath_fixed_cmp(a, b: int64): cint =
  ## -1/0/1, scale-invariant: two Q-format values of the same `frac_bits`
  ## compare as their raw words, order-preserving.
  ensureRuntime()
  cint(cmp(a, b))

proc unimath_fixed_abs(a: int64): int64 =
  ## Absolute value, clamped (the raw `low(int64)` word has no positive int64
  ## counterpart; clamps to `high(int64)` rather than overflow, never raises).
  ensureRuntime()
  clampToInt64(initBigInt(abs(initBigInt(a)), false))

proc unimath_fixed_sign(a: int64): cint =
  ## -1/0/1, scale-invariant.
  ensureRuntime()
  if a > 0: 1 elif a < 0: -1 else: 0

proc unimath_fixed_clamp(val, lo, hi: int64): int64 =
  ## Clamp `val` to `[lo, hi]` (raw Q-format words, same `frac_bits`).
  ensureRuntime()
  if val < lo: lo elif val > hi: hi else: val

proc unimath_fixed_floor_mod(a, b: int64): int64 =
  ## Floored modulo, scale-invariant (the scale cancels in `a mod b`, so the
  ## same floored-remainder adjustment as the integer case applies to the raw
  ## words directly). Returns 0 on division by zero (never raises).
  ensureRuntime()
  if b == 0: return 0
  let r = a mod b
  if (r > 0 and b < 0) or (r < 0 and b > 0): r + b else: r

# The remaining Fixed utilities (floor/ceil/round/lerp) need the fractional-bit
# boundary, unlike the scale-invariant ops above; like the CORDIC/LUT/gamma/
# bessel functions elsewhere in this file, they fix Q32.32 (`fxOf`) rather than
# taking a runtime `frac_bits` -- there is no single C ABI shape for a value
# genuinely generic over `static[int] FracBits`. Computed via the same exact
# BigInt intermediate + clamp the rest of this file uses, not by calling the
# Fixed[int64,32] operators directly: `ceil`/`round`/`lerp` go through the
# overflow-checked Fixed `+` (raises `OverflowDefect` out of range), and this
# ABI never raises.
const Q32Frac = 32
const Q32One = 1'i64 shl Q32Frac
const Q32Mask = Q32One - 1'i64

proc unimath_fixed_floor(a: int64): int64 =
  ## Q32.32 floor: clear the fractional bits (no overflow possible).
  ensureRuntime()
  a and not Q32Mask

proc unimath_fixed_ceil(a: int64): int64 =
  ## Q32.32 ceiling, clamped.
  ensureRuntime()
  if (a and Q32Mask) == 0: return a
  clampToInt64(initBigInt(a and not Q32Mask) + initBigInt(Q32One))

proc unimath_fixed_round(a: int64): int64 =
  ## Q32.32 round-half-up, clamped.
  ensureRuntime()
  let summed = clampToInt64(initBigInt(a) + initBigInt(Q32One shr 1))
  summed and not Q32Mask

proc unimath_fixed_lerp(a, b, t: int64): int64 =
  ## Q32.32 linear interpolation `a + (b - a) * t`, clamped.
  ensureRuntime()
  clampToInt64(initBigInt(a) +
    ((initBigInt(b) - initBigInt(a)) * initBigInt(t)) shr Natural(Q32Frac))

# ------------------------------------------------------------------------------
# BigFloat — handle = pinned ref BigFloat. Default 256-bit precision. Never
# raises: NULL on nil handle / Inf/NaN input / division by zero; `to_f64`
# returns ±Inf/±0 on overflow/underflow (matches `toFloat64`).
# ------------------------------------------------------------------------------

proc unimath_bigfloat_from_f64(v: float64): pointer =
  ## Build from a float64. NULL on Inf/NaN (not representable).
  ensureRuntime()
  try: pinFloat(initBigFloat(v))
  except ValueError: nil

proc unimath_bigfloat_from_i64(v: int64): pointer =
  ## Build from an int64, exactly (via BigInt, no float64 detour).
  ensureRuntime()
  pinFloat(fromBigInt(initBigInt(v)))

proc unimath_bigfloat_to_f64(h: pointer): float64 =
  ## Correctly-rounded float64. 0.0 on a nil handle.
  ensureRuntime()
  toFloat64(bfOf(h))

proc unimath_bigfloat_add(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinFloat(bfOf(a) + bfOf(b))

proc unimath_bigfloat_sub(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinFloat(bfOf(a) - bfOf(b))

proc unimath_bigfloat_mul(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinFloat(bfOf(a) * bfOf(b))

proc unimath_bigfloat_div(a, b: pointer): pointer =
  ## NULL on a nil handle or division by zero (never raises).
  ensureRuntime()
  if a == nil or b == nil: return nil
  if isZero(bfOf(b)): return nil
  pinFloat(bfOf(a) / bfOf(b))

proc unimath_bigfloat_cmp(a, b: pointer): cint =
  ## -1 / 0 / 1. Returns 0 if either handle is nil.
  ensureRuntime()
  if a == nil or b == nil: return cint(0)
  cint(cmp(bfOf(a), bfOf(b)))

proc unimath_bigfloat_is_zero(h: pointer): cint =
  ## 0 on a nil handle (not the zero value).
  ensureRuntime()
  if h == nil: return cint(0)
  cint(isZero(bfOf(h)))

proc unimath_bigfloat_neg(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinFloat(-bfOf(a))

proc unimath_bigfloat_abs(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinFloat(abs(bfOf(a)))

proc unimath_bigfloat_from_bigint(h: pointer): pointer =
  ## Exact conversion (via the BigInt's own mantissa, no float64 detour).
  ## NULL on a nil handle.
  ensureRuntime()
  if h == nil: return nil
  pinFloat(fromBigInt(bigOf(h)))

proc unimath_bigfloat_destroy(h: pointer) =
  ensureRuntime()
  unrefBigFloat(h)

# ------------------------------------------------------------------------------
# Rational — handle = pinned ref Rational[BigInt] (unbounded exact). Never
# raises: NULL on nil handle / zero denominator / division by zero; `to_f64`
# returns 0.0 on a nil handle.
# ------------------------------------------------------------------------------

proc unimath_rational_from_i64(num, den: int64): pointer =
  ## `num/den` reduced. NULL on a zero denominator (never raises).
  ensureRuntime()
  if den == 0: return nil
  pinRational(initRational(initBigInt(num), initBigInt(den)))

proc unimath_rational_from_bigint(num, den: pointer): pointer =
  ## `num/den` from BigInt handles, reduced. NULL on a nil handle or a zero
  ## denominator.
  ensureRuntime()
  if num == nil or den == nil: return nil
  if isZero(bigOf(den)): return nil
  pinRational(initRational(bigOf(num), bigOf(den)))

proc unimath_rational_to_f64(h: pointer): float64 =
  ## Approximate float64 (rounded division). 0.0 on a nil handle.
  ensureRuntime()
  toFloat64(ratOf(h))

proc unimath_rational_num(h: pointer): pointer =
  ## Numerator as a new pinned BigInt handle (caller owns it). NULL on nil.
  ensureRuntime()
  if h == nil: return nil
  pin(ratOf(h).num)

proc unimath_rational_den(h: pointer): pointer =
  ## Denominator as a new pinned BigInt handle (caller owns it). NULL on nil.
  ensureRuntime()
  if h == nil: return nil
  pin(ratOf(h).den)

proc unimath_rational_add(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinRational(ratOf(a) + ratOf(b))

proc unimath_rational_sub(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinRational(ratOf(a) - ratOf(b))

proc unimath_rational_mul(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinRational(ratOf(a) * ratOf(b))

proc unimath_rational_div(a, b: pointer): pointer =
  ## NULL on a nil handle or division by zero (never raises).
  ensureRuntime()
  if a == nil or b == nil: return nil
  if isZero(ratOf(b)): return nil
  pinRational(ratOf(a) / ratOf(b))

proc unimath_rational_neg(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinRational(-ratOf(a))

proc unimath_rational_abs(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinRational(abs(ratOf(a)))

proc unimath_rational_cmp(a, b: pointer): cint =
  ## -1 / 0 / 1. Returns 0 if either handle is nil.
  ensureRuntime()
  if a == nil or b == nil: return cint(0)
  cint(cmp(ratOf(a), ratOf(b)))

proc unimath_rational_is_zero(h: pointer): cint =
  ## 0 on a nil handle (not the zero value).
  ensureRuntime()
  if h == nil: return cint(0)
  cint(isZero(ratOf(h)))

proc unimath_rational_is_one(h: pointer): cint =
  ## 0 on a nil handle (not the value one).
  ensureRuntime()
  if h == nil: return cint(0)
  cint(isOne(ratOf(h)))

proc unimath_rational_destroy(h: pointer) =
  ensureRuntime()
  unrefRational(h)

# ------------------------------------------------------------------------------
# Interval — value type (lo, hi doubles). Never raises: domain errors clamp the
# input to the valid domain; a wholly out-of-domain input (sqrt of a negative
# interval, ln of a non-positive interval) returns the NaN interval as a
# sentinel; division by an interval containing zero is unbounded -> (-Inf, Inf).
# ------------------------------------------------------------------------------

proc unimath_interval_from_f64(lo, hi: float64): IntervalC =
  ensureRuntime()
  IntervalC(lo: lo, hi: hi)

proc unimath_interval_lo(a: IntervalC): float64 =
  ensureRuntime()
  a.lo
proc unimath_interval_hi(a: IntervalC): float64 =
  ensureRuntime()
  a.hi

proc unimath_interval_add(a, b: IntervalC): IntervalC =
  ensureRuntime()
  let r = initInterval(a.lo, a.hi) + initInterval(b.lo, b.hi)
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_sub(a, b: IntervalC): IntervalC =
  ensureRuntime()
  let r = initInterval(a.lo, a.hi) - initInterval(b.lo, b.hi)
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_mul(a, b: IntervalC): IntervalC =
  ensureRuntime()
  let r = initInterval(a.lo, a.hi) * initInterval(b.lo, b.hi)
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_div(a, b: IntervalC): IntervalC =
  ensureRuntime()
  let bi = initInterval(b.lo, b.hi)
  if isUncertain(bi): return IntervalC(lo: -Inf, hi: Inf)
  let r = initInterval(a.lo, a.hi) / bi
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_sqrt(a: IntervalC): IntervalC =
  ensureRuntime()
  if a.hi < 0.0: return IntervalC(lo: NaN, hi: NaN)
  let lo = if a.lo < 0.0: 0.0 else: a.lo
  let r = sqrt(initInterval(lo, a.hi))
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_neg(a: IntervalC): IntervalC =
  ensureRuntime()
  let r = -initInterval(a.lo, a.hi)
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_pow(a: IntervalC; n: cint): IntervalC =
  ## `a^n`. The NaN interval on a negative `n` whose base interval contains
  ## zero (division by zero, never raises). Guarded up front rather than left
  ## to the `except`: catching a Defect only works while the library is built
  ## with `--panics:off`, which `clib`/`clibStatic`/`clibMsvc` now pass
  ## explicitly, but a cheap precondition needs no such dependency.
  ensureRuntime()
  let bi = initInterval(a.lo, a.hi)
  if n < 0 and isUncertain(bi):
    return IntervalC(lo: NaN, hi: NaN)
  try:
    let r = pow(initInterval(a.lo, a.hi), int(n))
    IntervalC(lo: r.lower, hi: r.upper)
  except DivByZeroDefect:
    IntervalC(lo: NaN, hi: NaN)

proc unimath_interval_arctan(a: IntervalC): IntervalC =
  ensureRuntime()
  let r = arctan(initInterval(a.lo, a.hi))
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_arctan2(y, x: IntervalC): IntervalC =
  ensureRuntime()
  let r = arctan2(initInterval(y.lo, y.hi), initInterval(x.lo, x.hi))
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_is_valid(a: IntervalC): cint =
  ## `lo <= hi` (0 if either bound is NaN).
  ensureRuntime()
  cint(isValid(initInterval(a.lo, a.hi)))

proc unimath_interval_width(a: IntervalC): float64 =
  ensureRuntime()
  width(initInterval(a.lo, a.hi))

proc unimath_interval_midpoint(a: IntervalC): float64 =
  ensureRuntime()
  midpoint(initInterval(a.lo, a.hi))

proc unimath_interval_contains(a: IntervalC; x: float64): cint =
  ## `x in [lo, hi]` (closed bounds).
  ensureRuntime()
  cint(contains(initInterval(a.lo, a.hi), x))

proc unimath_interval_contains_interval(outer, inner: IntervalC): cint =
  ## `inner ⊆ outer`.
  ensureRuntime()
  cint(contains(initInterval(outer.lo, outer.hi), initInterval(inner.lo, inner.hi)))

proc unimath_interval_overlaps(a, b: IntervalC): cint =
  ## `a ∩ b ≠ ∅`.
  ensureRuntime()
  cint(overlaps(initInterval(a.lo, a.hi), initInterval(b.lo, b.hi)))

proc unimath_interval_hull(a, b: IntervalC): IntervalC =
  ## Smallest interval containing both `a` and `b`.
  ensureRuntime()
  let r = hull(initInterval(a.lo, a.hi), initInterval(b.lo, b.hi))
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_intersect(a, b: IntervalC): IntervalC =
  ## `a ∩ b`. Valid (`lo <= hi`, check with `unimath_interval_is_valid`) iff
  ## `unimath_interval_overlaps(a, b)` -- the caller checks that, matching the
  ## underlying `intersect`'s own contract.
  ensureRuntime()
  let r = intersect(initInterval(a.lo, a.hi), initInterval(b.lo, b.hi))
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_exp(a: IntervalC): IntervalC =
  ensureRuntime()
  let r = exp(initInterval(a.lo, a.hi))
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_ln(a: IntervalC): IntervalC =
  ensureRuntime()
  if a.hi <= 0.0: return IntervalC(lo: NaN, hi: NaN)
  if a.lo <= 0.0:
    IntervalC(lo: -Inf, hi: up2(ln(a.hi)))
  else:
    let r = ln(initInterval(a.lo, a.hi))
    IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_sin(a: IntervalC): IntervalC =
  ensureRuntime()
  let r = sin(initInterval(a.lo, a.hi))
  IntervalC(lo: r.lower, hi: r.upper)

proc unimath_interval_cos(a: IntervalC): IntervalC =
  ensureRuntime()
  let r = cos(initInterval(a.lo, a.hi))
  IntervalC(lo: r.lower, hi: r.upper)

# ------------------------------------------------------------------------------
# Roots — integer square root (raw int64) and Newton-Raphson square root
# (float64, BigFloat handle). Never raises: a negative input clamps to 0
# (isqrt) / NaN (float64 sqrt) / NULL (BigFloat sqrt) instead of raising.
# ------------------------------------------------------------------------------

proc unimath_isqrt_i64(n: int64): int64 =
  ## Integer square root, clamped to the int64 range (exact BigInt intermediate,
  ## no int64 overflow). 0 on a negative input (never raises).
  ensureRuntime()
  if n < 0: return 0
  clampToInt64(isqrt(initBigInt(n)))

proc unimath_sqrt_newton_f64(x: float64): float64 =
  ## Newton-Raphson square root. NaN on a negative input (never raises).
  ensureRuntime()
  if x < 0.0: return NaN
  sqrtNewtonGeneric(x)

proc unimath_sqrt_newton_bigfloat(h: pointer): pointer =
  ## Newton-Raphson square root of a BigFloat. NULL on a nil handle or a
  ## negative input (never raises).
  ensureRuntime()
  if h == nil: return nil
  let b = bfOf(h)
  if b < zero(BigFloat): return nil
  pinFloat(sqrtNewtonGeneric(b))

# ------------------------------------------------------------------------------
# Exponential — Taylor exp, Taylor ln(1+x), and the generic ln(z), over float64
# and BigFloat. Never raises: a nil BigFloat handle returns NULL; an out-of-
# domain log (lnTaylor with x <= -1, lnGeneric with z <= 0) returns NaN / NULL.
# ------------------------------------------------------------------------------

proc unimath_exp_taylor_f64(x: float64): float64 =
  ## Taylor `exp(x)`. Defined everywhere (never raises).
  ensureRuntime()
  expTaylor(x)

proc unimath_ln_taylor_f64(x: float64): float64 =
  ## Taylor `ln(1+x)`. NaN on `x <= -1` (never raises).
  ensureRuntime()
  if 1.0 + x <= 0.0: return NaN
  lnTaylor(x)

proc unimath_ln_generic_f64(z: float64): float64 =
  ## Generic `ln(z)` for any positive z. NaN on `z <= 0` or non-finite
  ## (never raises; the reduced `float_math.ln` path round-trips through a
  ## 256-bit BigFloat, so `initBigFloat` is guarded against Inf/NaN).
  ensureRuntime()
  if not (z > 0.0 and z < Inf): return NaN
  toFloat64(ln(initBigFloat(z, 256)))

proc unimath_exp_taylor_bigfloat(h: pointer): pointer =
  ## Taylor `exp` of a BigFloat. NULL on a nil handle (never raises).
  ensureRuntime()
  if h == nil: return nil
  pinFloat(expTaylor(bfOf(h)))

proc unimath_ln_generic_bigfloat(h: pointer): pointer =
  ## Generic `ln(z)` of a BigFloat via the reduced `float_math.ln` path
  ## (mantissa range reduction). NULL on a nil handle or `z <= 0`
  ## (never raises).
  ensureRuntime()
  if h == nil: return nil
  let b = bfOf(h)
  if b <= zero(BigFloat): return nil
  pinFloat(ln(b))

# ------------------------------------------------------------------------------
# Trigonometry — generic Taylor sin/cos/atan over float64, and the fixed-point
# CORDIC/LUT/Chebyshev cores over Q32.32 (`Fixed[int64, 32]`). The fixed-point
# procs take the raw Q-format int64; angles are mod-reduced to `[0, 2pi)` first
# so CORDIC's range-reduction loop is bounded, and coordinates are clamped so
# the CORDIC gain (~1.646x) cannot overflow int64. Never raises.
# ------------------------------------------------------------------------------

const
  twoPiQ32 = int64(2.0 * 3.14159265358979323846 * float(uint64(1) shl 32))
    ## `2*pi` in Q32.32, for angle mod-reduction.
  cordicMaxQ = (int64(1) shl 62)
    ## Safe input bound: the CORDIC gain grows x by ~1.646x, so a raw value
    ## below `2^62` stays inside `int64` after the full iteration.

proc reduceQ32(a: int64): int64 {.inline.} =
  ## Fold a raw Q32.32 angle into `[0, 2pi)` so CORDIC's while-loop reduction
  ## is bounded (a huge raw angle would otherwise loop `~|a|/2pi` times).
  var r = a mod twoPiQ32
  if r < 0: r += twoPiQ32
  r

proc clampQ32(a: int64): int64 {.inline.} =
  ## Clamp a raw Q32.32 value into the safe CORDIC input range.
  max(-cordicMaxQ, min(a, cordicMaxQ))

proc unimath_taylor_sin_f64(x: float64): float64 =
  ## `sin(x)` via the generic Taylor series (float64).
  ensureRuntime()
  sinTaylor(x)

proc unimath_taylor_cos_f64(x: float64): float64 =
  ## `cos(x)` via the generic Taylor series (float64).
  ensureRuntime()
  cosTaylor(x)

proc unimath_taylor_atan_f64(x: float64): float64 =
  ## `atan(x)` via the generic Taylor series (float64).
  ensureRuntime()
  atanTaylor(x)

proc unimath_cordic_sin(q: int64): int64 =
  ## `sin` of a Q32.32 angle via CORDIC. The angle is mod-reduced first.
  ensureRuntime()
  sinCordic(initFixed[int64, 32](reduceQ32(q))).data

proc unimath_cordic_cos(q: int64): int64 =
  ## `cos` of a Q32.32 angle via CORDIC. The angle is mod-reduced first.
  ensureRuntime()
  cosCordic(initFixed[int64, 32](reduceQ32(q))).data

proc unimath_cordic_atan2(y, x: int64): int64 =
  ## `atan2(y, x)` of Q32.32 coordinates via CORDIC vectoring. The origin
  ## returns 0 by convention; coordinates are clamped to the safe range.
  ensureRuntime()
  atan2Cordic(initFixed[int64, 32](clampQ32(y)),
              initFixed[int64, 32](clampQ32(x))).data

proc unimath_lut_sin(q: int64): int64 =
  ## `sin` of a Q32.32 angle via the compile-time LUT (nearest-neighbour).
  ensureRuntime()
  sin_lut(initFixed[int64, 32](reduceQ32(q))).data

proc unimath_lut_cos(q: int64): int64 =
  ## `cos` of a Q32.32 angle via the compile-time LUT (nearest-neighbour).
  ensureRuntime()
  cos_lut(initFixed[int64, 32](reduceQ32(q))).data

proc unimath_chebyshev_tan(q: int64): int64 =
  ## `tan` of a Q32.32 angle via the Chebyshev minimax polynomial on
  ## `[-pi/4, pi/4]`. The input is clamped to the safe range; reduce to the
  ## primary interval on the host for angles outside it.
  ensureRuntime()
  tanChebyshev(initFixed[int64, 32](clampQ32(q))).data

# ------------------------------------------------------------------------------
# Hyperbolic — fixed-point CORDIC `sinh`/`cosh`/`tanh`/`exp` over Q32.32. The
# core raises `ValueError` outside the convergence domain `|z| <= ~1.1182`
# (hyperbolic functions are not periodic — no range reduction); the C ABI never
# raises, so the angle is clamped to the budget first. The clamped (capped)
# result for an out-of-budget input is the value at the boundary, not a raise.
# Use the BigFloat exp/sinh/cosh for larger arguments.
# ------------------------------------------------------------------------------

const
  hyperbolicBudgetQ32 = int64(1.10 * float(uint64(1) shl 32))
    ## Safe clamp below the CORDIC hyperbolic convergence budget
    ## `sum atanh(2^-i) ~ 1.1182`; keeps the in-core guard from raising.

proc clampHyperbolicQ32(a: int64): int64 {.inline.} =
  max(-hyperbolicBudgetQ32, min(a, hyperbolicBudgetQ32))

proc unimath_cordic_sinh(q: int64): int64 =
  ## `sinh` of a Q32.32 angle via CORDIC. The angle is clamped to the
  ## convergence domain first.
  ensureRuntime()
  sinhCordic(initFixed[int64, 32](clampHyperbolicQ32(q))).data

proc unimath_cordic_cosh(q: int64): int64 =
  ## `cosh` of a Q32.32 angle via CORDIC. The angle is clamped to the
  ## convergence domain first.
  ensureRuntime()
  coshCordic(initFixed[int64, 32](clampHyperbolicQ32(q))).data

proc unimath_cordic_tanh(q: int64): int64 =
  ## `tanh` of a Q32.32 angle via CORDIC. The angle is clamped to the
  ## convergence domain first.
  ensureRuntime()
  tanhCordic(initFixed[int64, 32](clampHyperbolicQ32(q))).data

proc unimath_cordic_exp(q: int64): int64 =
  ## `e^x` of a Q32.32 angle via CORDIC (`cosh + sinh`). The angle is clamped
  ## to the convergence domain first.
  ensureRuntime()
  expCordic(initFixed[int64, 32](clampHyperbolicQ32(q))).data

# ------------------------------------------------------------------------------
# Special — orthogonal polynomials, erf, Gamma, factorial, Bessel J0. These are
# the self-contained float64 paths (no fixed-point/Q32 pinning): the polynomials
# are pure three-term recurrences, `erf`/`besselJ0` are term-ratio series, and
# `gammaLanczosFloat` is the closed Lanczos approximation. The C ABI never
# raises: `gamma` returns NaN at the non-positive-integer poles (where the Nim
# core raises `ValueError`), and `factorial` returns 0 for `n < 0`.
# ------------------------------------------------------------------------------

proc unimath_chebyshev_t(n: cint; x: cdouble): cdouble =
  ## Chebyshev polynomial of the first kind `T_n(x)`, float64.
  ensureRuntime()
  chebyshevT(n.int, x.float64).float64

proc unimath_chebyshev_u(n: cint; x: cdouble): cdouble =
  ## Chebyshev polynomial of the second kind `U_n(x)`, float64.
  ensureRuntime()
  chebyshevU(n.int, x.float64).float64

proc unimath_legendre(n: cint; x: cdouble): cdouble =
  ## Legendre polynomial `P_n(x)`, float64.
  ensureRuntime()
  legendreP(n.int, x.float64).float64

proc unimath_hermite(n: cint; x: cdouble): cdouble =
  ## Hermite polynomial `H_n(x)`, float64.
  ensureRuntime()
  hermiteH(n.int, x.float64).float64

proc unimath_erf(x: cdouble): cdouble =
  ## Error function over the full float64 domain.
  ensureRuntime()
  error_functions.erf(x.float64, 32, PI, sqrtF64Abi, expF64Abi).float64

proc unimath_gamma(x: cdouble): cdouble =
  ## `Gamma(x)` via Lanczos (g=7, n=9), float64. Returns NaN at the
  ## non-positive-integer poles (the Nim core raises `ValueError` there); the
  ## C ABI never raises.
  ensureRuntime()
  if x <= 0.0 and x == round(x):
    return NaN
  gammaLanczosFloat(x.float64).float64

proc unimath_factorial(n: cint): cdouble =
  ## `n!` for non-negative `n` (0 for `n < 0`, undefined), float64.
  ensureRuntime()
  gamma.factorial[float64](n.int).float64

proc unimath_bessel_j0(x: cdouble): cdouble =
  ## Bessel `J0(x)` via the power series (15 terms), float64.
  ensureRuntime()
  besselJ0(x.float64, 15).float64

# ------------------------------------------------------------------------------
# Constants — `pi`/`e` for BigFloat (handle, 256-bit) and Fixed (raw Q32.32).
# The BigFloat handles are pinned refs the C host owns until
# `unimath_bigfloat_destroy`; the Fixed constants are raw `int64` Q32.32 words.
# ------------------------------------------------------------------------------

proc unimath_pi_bigfloat(): pointer =
  ## `pi` as a 256-bit BigFloat handle (Machin's formula). Destroy with
  ## `unimath_bigfloat_destroy`.
  ensureRuntime()
  pinFloat(piBigFloat(256))

proc unimath_e_bigfloat(): pointer =
  ## `e` as a 256-bit BigFloat handle (the `exp(1)` series). Destroy with
  ## `unimath_bigfloat_destroy`.
  ensureRuntime()
  pinFloat(eBigFloat(256))

proc unimath_pi_fixed(): int64 =
  ## `pi` as a raw Q32.32 word (the float64 literal rounded to the grid).
  ensureRuntime()
  piFixed[int64, 32]().data

proc unimath_e_fixed(): int64 =
  ## `e` as a raw Q32.32 word (the float64 literal rounded to the grid).
  ensureRuntime()
  eFixed[int64, 32]().data

# ------------------------------------------------------------------------------
# Reduction — BigFloat trig stage-1 range reduction `r = x - round(x/2pi)·2pi`
# into `[-pi, pi]`. Returns a new pinned handle (destroy with
# `unimath_bigfloat_destroy`); nil in -> nil out (the C ABI never raises).
# ------------------------------------------------------------------------------

proc unimath_bigfloat_reduce(h: pointer): pointer =
  ## Reduce a BigFloat argument mod `2*pi` into `[-pi, pi]`.
  ensureRuntime()
  if h == nil: return nil
  pinFloat(reduceModTwoPi(bfOf(h)))

# ------------------------------------------------------------------------------
# float_math — range-reduced BigFloat transcendentals. Each returns a new
# pinned handle (destroy with `unimath_bigfloat_destroy`); nil in -> nil out.
# Domain errors map to NULL (the C ABI never raises): `ln`/`pow` of a non-
# positive base, `sqrt` of a negative, `tan` at a cos-zero singularity.
# ------------------------------------------------------------------------------

proc unimath_bigfloat_sin(h: pointer): pointer =
  ## `sin(x)` with octant range reduction.
  ensureRuntime()
  if h == nil: return nil
  pinFloat(sin(bfOf(h)))

proc unimath_bigfloat_sin_terms(h: pointer; terms: cint): pointer =
  ensureRuntime()
  if h == nil: return nil
  pinFloat(sin(bfOf(h), terms.int))

proc unimath_bigfloat_cos(h: pointer): pointer =
  ## `cos(x)` with octant range reduction.
  ensureRuntime()
  if h == nil: return nil
  pinFloat(cos(bfOf(h)))

proc unimath_bigfloat_cos_terms(h: pointer; terms: cint): pointer =
  ensureRuntime()
  if h == nil: return nil
  pinFloat(cos(bfOf(h), terms.int))

proc unimath_bigfloat_tan(h: pointer): pointer =
  ## `tan(x) = sin(x)/cos(x)`. NULL on a nil handle or a cos-zero singularity.
  ensureRuntime()
  if h == nil: return nil
  try:
    pinFloat(tan(bfOf(h)))
  except DivByZeroDefect:
    nil

proc unimath_bigfloat_tan_terms(h: pointer; terms: cint): pointer =
  ensureRuntime()
  if h == nil: return nil
  try:
    pinFloat(tan(bfOf(h), terms.int))
  except DivByZeroDefect:
    nil

proc unimath_bigfloat_exp(h: pointer): pointer =
  ## `exp(x)` by scaling-and-squaring.
  ensureRuntime()
  if h == nil: return nil
  pinFloat(exp(bfOf(h)))

proc unimath_bigfloat_exp_terms(h: pointer; terms: cint): pointer =
  ensureRuntime()
  if h == nil: return nil
  pinFloat(exp(bfOf(h), terms.int))

proc unimath_bigfloat_ln(h: pointer): pointer =
  ## `ln(x)` with mantissa range reduction. NULL on a nil handle or `x <= 0`.
  ensureRuntime()
  if h == nil: return nil
  let b = bfOf(h)
  if b <= zero(BigFloat): return nil
  pinFloat(ln(b))

proc unimath_bigfloat_ln_terms(h: pointer; terms: cint): pointer =
  ensureRuntime()
  if h == nil: return nil
  let b = bfOf(h)
  if b <= zero(BigFloat): return nil
  pinFloat(ln(b, terms.int))

proc unimath_bigfloat_sqrt(h: pointer): pointer =
  ## `sqrt(x)` via Newton iteration. NULL on a nil handle or a negative input.
  ensureRuntime()
  if h == nil: return nil
  let b = bfOf(h)
  if b < zero(BigFloat): return nil
  pinFloat(sqrt(b))

proc unimath_bigfloat_arctan(h: pointer): pointer =
  ## `arctan(x)` with argument reduction.
  ensureRuntime()
  if h == nil: return nil
  pinFloat(arctan(bfOf(h)))

proc unimath_bigfloat_arctan_terms(h: pointer; terms: cint): pointer =
  ensureRuntime()
  if h == nil: return nil
  pinFloat(arctan(bfOf(h), terms.int))

proc unimath_bigfloat_arctan2(y, x: pointer): pointer =
  ## `arctan2(y, x)` with quadrant dispatch. NULL if either handle is nil.
  ensureRuntime()
  if y == nil or x == nil: return nil
  pinFloat(arctan2(bfOf(y), bfOf(x)))

proc unimath_bigfloat_arctan2_terms(y, x: pointer; terms: cint): pointer =
  ensureRuntime()
  if y == nil or x == nil: return nil
  pinFloat(arctan2(bfOf(y), bfOf(x), terms.int))

proc unimath_bigfloat_pow_int(h: pointer; n: cint): pointer =
  ## `x^n`, integer exponent (repeated squaring). NULL on a nil handle.
  ensureRuntime()
  if h == nil: return nil
  pinFloat(pow(bfOf(h), n.int))

proc unimath_bigfloat_pow(h, e: pointer): pointer =
  ## `x^e = exp(e·ln(x))` for `x > 0`. NULL on a nil handle or a non-positive
  ## base.
  ensureRuntime()
  if h == nil or e == nil: return nil
  let b = bfOf(h)
  if not (b > zero(BigFloat)): return nil
  pinFloat(pow(b, bfOf(e)))

proc unimath_bigfloat_pow_terms(h, e: pointer; terms: cint): pointer =
  ensureRuntime()
  if h == nil or e == nil: return nil
  let b = bfOf(h)
  if not (b > zero(BigFloat)): return nil
  pinFloat(pow(b, bfOf(e), terms.int))

# ------------------------------------------------------------------------------
# rational_math — Rational[BigInt] transcendentals (exact per term, truncated).
# Each returns a new pinned handle (destroy with `unimath_rational_destroy`);
# nil in -> nil out. Domain errors map to NULL (the C ABI never raises): `ln`/
# `pow` of a non-positive base, `sqrt` of a negative, `tan` at a cos-zero
# singularity. The series terms default as in the Nim core (5 for trig, 10 for
# exp/ln); the unbounded BigInt backend does not overflow.
# ------------------------------------------------------------------------------

proc unimath_rational_sin(h: pointer): pointer =
  ## `sin(x)` via the generic Taylor core (truncated at 5 terms).
  ensureRuntime()
  if h == nil: return nil
  pinRational(sin(ratOf(h)))

proc unimath_rational_cos(h: pointer): pointer =
  ## `cos(x)` via the generic Taylor core (truncated at 5 terms).
  ensureRuntime()
  if h == nil: return nil
  pinRational(cos(ratOf(h)))

proc unimath_rational_tan(h: pointer): pointer =
  ## `tan(x) = sin(x)/cos(x)`. NULL on a nil handle or a cos-zero singularity.
  ensureRuntime()
  if h == nil: return nil
  try:
    pinRational(tan(ratOf(h)))
  except DivByZeroDefect:
    nil

proc unimath_rational_exp(h: pointer): pointer =
  ## `e^x` as an exact rational approximation (truncated at 10 terms).
  ensureRuntime()
  if h == nil: return nil
  pinRational(exp(ratOf(h)))

proc unimath_rational_ln(h: pointer): pointer =
  ## `ln(x)` via the atanh series. NULL on a nil handle or `x <= 0`.
  ensureRuntime()
  if h == nil: return nil
  let r = ratOf(h)
  if r <= zero(Rational[BigInt]): return nil
  try:
    pinRational(ln(r))
  except ValueError:
    nil

proc unimath_rational_sqrt(h: pointer): pointer =
  ## `sqrt(x)` via Newton's method. NULL on a nil handle or a negative input.
  ensureRuntime()
  if h == nil: return nil
  let r = ratOf(h)
  if r < zero(Rational[BigInt]): return nil
  try:
    pinRational(sqrt(r))
  except ValueError:
    nil

proc unimath_rational_atan(h: pointer): pointer =
  ## `atan(x)` with range reduction (`pi` as `355/113`).
  ensureRuntime()
  if h == nil: return nil
  pinRational(atan(ratOf(h)))

proc unimath_rational_atan2(y, x: pointer): pointer =
  ## `atan2(y, x)` with quadrant dispatch. NULL if either handle is nil.
  ensureRuntime()
  if y == nil or x == nil: return nil
  pinRational(atan2(ratOf(y), ratOf(x)))

proc unimath_rational_pow(h, e: pointer): pointer =
  ## `base^exponent = exp(exponent·ln(base))` for `base > 0`. NULL on a nil
  ## handle or a non-positive base.
  ensureRuntime()
  if h == nil or e == nil: return nil
  let b = ratOf(h)
  if not (b > zero(Rational[BigInt])): return nil
  try:
    pinRational(pow(b, ratOf(e)))
  except ValueError:
    nil

# ------------------------------------------------------------------------------
# math_router — Fixed[int64, 32] (Q32.32) transcendentals via the auto-dispatch
# cores (CORDIC / Chebyshev / Newton / Taylor). The raw Q32.32 word is the
# `data` field of `Fixed[int64, 32]`; each proc wraps it, dispatches, and
# returns the result word. The C ABI never raises: a domain error or an
# out-of-convergence argument (hyperbolic/`exp` CORDIC needs `|z| <= ~1.1182`)
# clamps to `0` (the type's default).
# ------------------------------------------------------------------------------

proc unimath_fixed_sin(q: int64): int64 =
  ## `sin(q)` (Q32.32) via CORDIC. Clamps to 0 on a domain/overflow defect.
  ensureRuntime()
  try: sin(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_cos(q: int64): int64 =
  ## `cos(q)` (Q32.32) via CORDIC. Clamps to 0 on a domain/overflow defect.
  ensureRuntime()
  try: cos(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_tan(q: int64): int64 =
  ## `tan(q)` (Q32.32) via Chebyshev. Clamps to 0 on a singularity/overflow.
  ensureRuntime()
  try: tan(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_exp(q: int64): int64 =
  ## `exp(q)` (Q32.32) via hyperbolic CORDIC scaling-and-squaring (in-domain
  ## up to the Q32.32 representable ceiling, `q` up to ~21.5), else (result
  ## overflow) clamps to 0.
  ensureRuntime()
  try: exp(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_ln(q: int64): int64 =
  ## `ln(q)` (Q32.32) via the area-hyperbolic-tangent series (globally
  ## convergent for any `q > 0`). `q <= 0` clamps to 0.
  ensureRuntime()
  try: ln(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_sqrt(q: int64): int64 =
  ## `sqrt(q)` (Q32.32) via Newton. `q < 0` clamps to 0.
  ensureRuntime()
  try: sqrt(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_atan(q: int64): int64 =
  ## `atan(q)` (Q32.32) via CORDIC. Clamps to 0 on a defect.
  ensureRuntime()
  try: atan(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_atan2(y, x: int64): int64 =
  ## `atan2(y, x)` (Q32.32) via CORDIC. Clamps to 0 on a defect.
  ensureRuntime()
  try: atan2(fxOf(y), fxOf(x)).data
  except CatchableError, Defect: 0

proc unimath_fixed_sinh(q: int64): int64 =
  ## `sinh(q)` (Q32.32) via exponentials; overflow clamps to 0.
  ensureRuntime()
  try: sinh(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_cosh(q: int64): int64 =
  ## `cosh(q)` (Q32.32) via exponentials; overflow clamps to 0.
  ensureRuntime()
  try: cosh(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_tanh(q: int64): int64 =
  ## `tanh(q)` (Q32.32) via a stable exponential identity over the full domain.
  ensureRuntime()
  try: tanh(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_pow(base, exponent: int64): int64 =
  ## `base^exponent` (Q32.32) via `exp(exponent·ln(base))`, domain `base > 0`.
  ## Out-of-domain or a `base^exponent` result past the Q32.32 ceiling clamps
  ## to 0.
  ensureRuntime()
  try: pow(fxOf(base), fxOf(exponent)).data
  except CatchableError, Defect: 0

proc unimath_fixed_asin(q: int64): int64 =
  ## `asin(q)` (Q32.32) via `atan2(q, sqrt(1-q^2))`, domain `|q| <= 1`.
  ## Out-of-domain or out-of-convergence clamps to 0.
  ensureRuntime()
  try: asin(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_acos(q: int64): int64 =
  ## `acos(q)` (Q32.32) via `atan2(sqrt(1-q^2), q)`, domain `|q| <= 1`.
  ## Out-of-domain or out-of-convergence clamps to 0.
  ensureRuntime()
  try: acos(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_asinh(q: int64): int64 =
  ## `asinh(q)` (Q32.32) via `ln(q + sqrt(q^2+1))`. Clamps to 0 on a defect.
  ensureRuntime()
  try: asinh(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_acosh(q: int64): int64 =
  ## `acosh(q)` (Q32.32) via `ln(q + sqrt(q^2-1))`, domain `q >= 1`.
  ## Out-of-domain or out-of-convergence clamps to 0.
  ensureRuntime()
  try: acosh(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_atanh(q: int64): int64 =
  ## `atanh(q)` (Q32.32) via `(1/2)*ln((1+q)/(1-q))`, domain `|q| < 1`.
  ## Out-of-domain or out-of-convergence clamps to 0.
  ensureRuntime()
  try: atanh(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_factorial(n: cint): int64 =
  ## `n!` (Q32.32), exact within range. 0 for `n < 0` (undefined).
  ensureRuntime()
  try: gamma.factorial[Fixed[int64, 32]](n.int).data
  except CatchableError, Defect: 0

proc unimath_fixed_erf(q: int64): int64 =
  ## `erf(q)` (Q32.32) via the Taylor core. Clamps to 0 on a defect.
  ensureRuntime()
  try: erf(fxOf(q)).data
  except CatchableError, Defect: 0

proc unimath_fixed_bessel_j0(q: int64): int64 =
  ## Bessel `J0(q)` (Q32.32) via the series core. Clamps to 0 on a defect.
  ensureRuntime()
  try: besselJ0(fxOf(q)).data
  except CatchableError, Defect: 0

# ------------------------------------------------------------------------------
# conversions — cross-type matrix across the handle / value surfaces. The C
# ABI never raises: nil in -> nil/0/NaN-interval out; a representation overflow
# (fixed target) or a NaN/Inf source (rational target) clamps to 0 / NULL.
# ------------------------------------------------------------------------------

proc unimath_rational_from_f64(v: float64): pointer =
  ## EXACT float64 -> `Rational[BigInt]` (no exponent limit). NaN/Inf -> NULL.
  ensureRuntime()
  try: pinRational(toRationalBig(v))
  except ValueError: nil

proc unimath_rational_from_fixed(q: int64; frac_bits: cint): pointer =
  ## EXACT raw Q-format fixed -> `Rational[BigInt]`: value = q / 2^frac_bits.
  ## Out-of-range `frac_bits` (negative, or above 63) -> NULL: a negative
  ## denominator width would be non-integer, and a large one allocates a
  ## multi-hundred-megabyte shift.
  ensureRuntime()
  if frac_bits < 0 or frac_bits > MaxFracBits: return nil
  pinRational(initRational(initBigInt(q), initBigInt(1) shl Natural(frac_bits)))

proc unimath_bigfloat_from_rational(h: pointer): pointer =
  ## ROUNDED Rational -> BigFloat (nearest, 256-bit). nil -> NULL.
  ensureRuntime()
  if h == nil: return nil
  pinFloat(toBigFloat(ratOf(h), 256, rmNearest))

proc unimath_bigint_from_bigfloat(h: pointer): pointer =
  ## TRUNCATED BigFloat -> BigInt. nil -> NULL.
  ensureRuntime()
  if h == nil: return nil
  pin(toBigInt(bfOf(h)))

proc unimath_bigint_from_rational(h: pointer): pointer =
  ## TRUNCATED Rational -> BigInt. nil -> NULL.
  ensureRuntime()
  if h == nil: return nil
  pin(toBigInt(ratOf(h)))

proc unimath_fixed_from_rational(h: pointer; frac_bits: cint): int64 =
  ## TRUNCATED `Rational[BigInt]` -> raw Q-format fixed:
  ## `data = (num * 2^frac_bits) div den`. nil -> 0; `frac_bits < 0` or a
  ## result that does not fit in 63 bits -> 0 (clamped, never raises).
  ensureRuntime()
  if h == nil or frac_bits < 0 or frac_bits > MaxFracBits: return 0
  try:
    let r = ratOf(h)
    let numMag = r.num.mag shl Natural(frac_bits)
    let q = numMag div r.den.mag
    if bitLength(q) > 63: return 0
    # `toInt64`, not `limbs[0]`: indexing the low limb only reconstructs the
    # value when a limb is 64 bits, and `bitLength(q) <= 63` admits values
    # spanning two limbs on a 32-bit limb build.
    var raw = if isZero(q): 0'i64 else: q.toInt64()
    if r.num.isNegative: raw = -raw
    raw
  except CatchableError, Defect:
    0

proc unimath_interval_from_bigfloat(h: pointer): IntervalC =
  ## ENCLOSURE BigFloat -> Interval. nil -> the NaN interval.
  ensureRuntime()
  if h == nil: return IntervalC(lo: NaN, hi: NaN)
  let i = toInterval(bfOf(h))
  IntervalC(lo: i.lower, hi: i.upper)

proc unimath_interval_from_rational(h: pointer): IntervalC =
  ## ENCLOSURE Rational -> Interval. nil -> the NaN interval.
  ensureRuntime()
  if h == nil: return IntervalC(lo: NaN, hi: NaN)
  let i = toInterval(ratOf(h))
  IntervalC(lo: i.lower, hi: i.upper)

proc unimath_interval_from_bigint(h: pointer): IntervalC =
  ## ENCLOSURE BigInt -> Interval. nil -> the NaN interval.
  ensureRuntime()
  if h == nil: return IntervalC(lo: NaN, hi: NaN)
  let i = toInterval(bigOf(h))
  IntervalC(lo: i.lower, hi: i.upper)

# ------------------------------------------------------------------------------
# Complex — value type (re, im doubles). Never raises: a domain error (division
# by zero, log of zero, a pole of tan/tanh) returns the NaN complex as a
# sentinel. Test it with `unimath_complex_is_nan`, not `==`: NaN compares
# unequal to itself.
#
# Branch cuts: principal values, `unimath_complex_arg` in (-pi, pi], the cut
# along the negative real axis. A negative real yields the +i root, so
# `unimath_csqrt(-1.0)` is 0+1i.
# ------------------------------------------------------------------------------

proc unimath_complex_from_f64(re, im: float64): ComplexC =
  ensureRuntime()
  ComplexC(re: re, im: im)

proc unimath_complex_re(z: ComplexC): float64 =
  ensureRuntime()
  z.re
proc unimath_complex_im(z: ComplexC): float64 =
  ensureRuntime()
  z.im

proc unimath_complex_is_nan(z: ComplexC): cint =
  ## 1 when either component is NaN — the sentinel check for every entry point
  ## below that can hit a domain error.
  ensureRuntime()
  cint(z.re != z.re or z.im != z.im)

proc unimath_complex_add(a, b: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(cxOf(a) + cxOf(b))

proc unimath_complex_sub(a, b: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(cxOf(a) - cxOf(b))

proc unimath_complex_mul(a, b: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(cxOf(a) * cxOf(b))

proc unimath_complex_div(a, b: ComplexC): ComplexC =
  ## The NaN complex on a zero divisor. Guarded up front rather than left to
  ## an `except`: catching a Defect only works while the library is built with
  ## `--panics:off`, and a cheap precondition needs no such dependency.
  ensureRuntime()
  if b.re == 0.0 and b.im == 0.0: return NaNComplexC
  cxTo(cxOf(a) / cxOf(b))

proc unimath_complex_neg(a: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(-cxOf(a))

proc unimath_complex_conj(a: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(conj(cxOf(a)))

proc unimath_complex_inv(a: ComplexC): ComplexC =
  ## `1/a`. The NaN complex on zero.
  ensureRuntime()
  if a.re == 0.0 and a.im == 0.0: return NaNComplexC
  cxTo(inv(cxOf(a)))

proc unimath_complex_abs(a: ComplexC): float64 =
  ## Modulus. Scaled by the larger component, so it stays finite where
  ## `sqrt(norm2)` would overflow.
  ensureRuntime()
  abs(cxOf(a))

proc unimath_complex_norm2(a: ComplexC): float64 =
  ## Squared modulus `re*re + im*im` — overflows to +Inf where `abs` does not.
  ensureRuntime()
  norm2(cxOf(a))

proc unimath_complex_arg(a: ComplexC): float64 =
  ## Principal argument in (-pi, pi]. `arg(0)` is 0.
  ensureRuntime()
  arg(cxOf(a))

proc unimath_complex_rect(r, theta: float64): ComplexC =
  ## Polar to Cartesian.
  ensureRuntime()
  cxTo(rect(r, theta))

proc unimath_complex_sqrt(a: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(sqrt(cxOf(a)))

proc unimath_complex_exp(a: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(exp(cxOf(a)))

proc unimath_complex_ln(a: ComplexC): ComplexC =
  ## The NaN complex on zero — no branch of the complex log is finite there.
  ensureRuntime()
  if a.re == 0.0 and a.im == 0.0: return NaNComplexC
  cxTo(ln(cxOf(a)))

proc unimath_complex_sin(a: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(sin(cxOf(a)))

proc unimath_complex_cos(a: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(cos(cxOf(a)))

proc unimath_complex_tan(a: ComplexC): ComplexC =
  ## The NaN complex at a pole (zero cosine).
  ensureRuntime()
  let z = cxOf(a)
  let c = cos(z)
  if c.re == 0.0 and c.im == 0.0: return NaNComplexC
  cxTo(sin(z) / c)

proc unimath_complex_sinh(a: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(sinh(cxOf(a)))

proc unimath_complex_cosh(a: ComplexC): ComplexC =
  ensureRuntime()
  cxTo(cosh(cxOf(a)))

proc unimath_complex_tanh(a: ComplexC): ComplexC =
  ## The NaN complex at a pole (zero hyperbolic cosine).
  ensureRuntime()
  let z = cxOf(a)
  let c = cosh(z)
  if c.re == 0.0 and c.im == 0.0: return NaNComplexC
  cxTo(sinh(z) / c)

proc unimath_complex_pow_int(a: ComplexC; n: cint): ComplexC =
  ## Integer power by binary exponentiation. `n == 0` is 1 for every base; a
  ## negative `n` on a zero base is the NaN complex.
  ensureRuntime()
  if n < 0 and a.re == 0.0 and a.im == 0.0: return NaNComplexC
  cxTo(pow(cxOf(a), int(n)))

proc unimath_complex_pow(a, b: ComplexC): ComplexC =
  ## Principal `a^b = exp(b * ln a)`. A zero base is the NaN complex — use
  ## `unimath_complex_pow_int` for the `0^0 == 1` convention.
  ensureRuntime()
  if a.re == 0.0 and a.im == 0.0: return NaNComplexC
  cxTo(pow(cxOf(a), cxOf(b)))

proc unimath_csqrt(x: float64): ComplexC =
  ## Square root of a REAL, returned as a complex: `unimath_csqrt(-1.0)` is
  ## 0+1i where the root has no real value. `unimath_sqrt_newton_f64` keeps
  ## its NaN-on-negative contract.
  ensureRuntime()
  cxTo(csqrt(x))

proc unimath_cln(x: float64): ComplexC =
  ## Logarithm of a REAL that promotes instead of failing: `unimath_cln(-1.0)`
  ## is 0 + pi*i. Zero is the NaN complex.
  ensureRuntime()
  if x == 0.0: return NaNComplexC
  cxTo(cln(x))

# ------------------------------------------------------------------------------
# Complex over BigFloat — handle = pinned `ref Complex[BigFloat]`, the same
# discipline as the BigFloat scalars. This is the multi-precision complex path:
# every function of the float64 section above, at the precision the components
# carry. Never raises: NULL in -> NULL out; a domain error returns NULL.
# ------------------------------------------------------------------------------

proc unimath_complex_bigfloat_from_bigfloat(re, im: pointer): pointer =
  ## Builds from two BigFloat handles, which the caller still owns and must
  ## destroy separately: the components are copied in, not adopted.
  ensureRuntime()
  if re == nil or im == nil: return nil
  pinCxFloat(complex(bfOf(re), bfOf(im)))

proc unimath_complex_bigfloat_from_f64(re, im: float64): pointer =
  ## NULL if either component is Inf or NaN, as the scalar constructor is.
  ensureRuntime()
  try: pinCxFloat(complex(initBigFloat(re), initBigFloat(im)))
  except ValueError: nil

proc unimath_complex_bigfloat_re(h: pointer): pointer =
  ## A NEW BigFloat handle for the real part; destroy it separately.
  ensureRuntime()
  if h == nil: return nil
  pinFloat(cxfOf(h).re)

proc unimath_complex_bigfloat_im(h: pointer): pointer =
  ensureRuntime()
  if h == nil: return nil
  pinFloat(cxfOf(h).im)

proc unimath_complex_bigfloat_is_zero(h: pointer): cint =
  ensureRuntime()
  if h == nil: return 0
  cint(cxfOf(h).isZero)

proc unimath_complex_bigfloat_add(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinCxFloat(cxfOf(a) + cxfOf(b))

proc unimath_complex_bigfloat_sub(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinCxFloat(cxfOf(a) - cxfOf(b))

proc unimath_complex_bigfloat_mul(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinCxFloat(cxfOf(a) * cxfOf(b))

proc unimath_complex_bigfloat_div(a, b: pointer): pointer =
  ## NULL on a zero divisor.
  ensureRuntime()
  if a == nil or b == nil or cxfOf(b).isZero: return nil
  pinCxFloat(cxfOf(a) / cxfOf(b))

proc unimath_complex_bigfloat_neg(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinCxFloat(-cxfOf(a))

proc unimath_complex_bigfloat_conj(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinCxFloat(conj(cxfOf(a)))

proc unimath_complex_bigfloat_inv(a: pointer): pointer =
  ensureRuntime()
  if a == nil or cxfOf(a).isZero: return nil
  pinCxFloat(inv(cxfOf(a)))

proc unimath_complex_bigfloat_abs(a: pointer): pointer =
  ## Modulus as a NEW BigFloat handle.
  ensureRuntime()
  if a == nil: return nil
  pinFloat(abs(cxfOf(a)))

proc unimath_complex_bigfloat_norm2(a: pointer): pointer =
  ## Squared modulus as a NEW BigFloat handle.
  ensureRuntime()
  if a == nil: return nil
  pinFloat(norm2(cxfOf(a)))

proc unimath_complex_bigfloat_arg(a: pointer): pointer =
  ## Principal argument as a NEW BigFloat handle.
  ensureRuntime()
  if a == nil: return nil
  pinFloat(arg(cxfOf(a)))

proc unimath_complex_bigfloat_sqrt(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinCxFloat(sqrt(cxfOf(a)))

proc unimath_complex_bigfloat_exp(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinCxFloat(exp(cxfOf(a)))

proc unimath_complex_bigfloat_ln(a: pointer): pointer =
  ## NULL on zero.
  ensureRuntime()
  if a == nil or cxfOf(a).isZero: return nil
  pinCxFloat(ln(cxfOf(a)))

proc unimath_complex_bigfloat_sin(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinCxFloat(sin(cxfOf(a)))

proc unimath_complex_bigfloat_cos(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinCxFloat(cos(cxfOf(a)))

proc unimath_complex_bigfloat_pow_int(a: pointer; n: cint): pointer =
  ## NULL on a negative `n` with a zero base; `n == 0` is 1 for every base.
  ensureRuntime()
  if a == nil: return nil
  if n < 0 and cxfOf(a).isZero: return nil
  pinCxFloat(pow(cxfOf(a), int(n)))

proc unimath_complex_bigfloat_pow(a, b: pointer): pointer =
  ## Principal `a^b = exp(b * ln a)`. NULL on a zero base.
  ensureRuntime()
  if a == nil or b == nil or cxfOf(a).isZero: return nil
  pinCxFloat(pow(cxfOf(a), cxfOf(b)))

proc unimath_csqrt_bigfloat(h: pointer): pointer =
  ## Square root of a REAL BigFloat, returned as a complex handle instead of
  ## failing on a negative argument.
  ensureRuntime()
  if h == nil: return nil
  pinCxFloat(csqrt(bfOf(h)))

proc unimath_cln_bigfloat(h: pointer): pointer =
  ## Logarithm of a REAL BigFloat as a complex handle. NULL on zero.
  ensureRuntime()
  if h == nil or bfOf(h).isZero: return nil
  pinCxFloat(cln(bfOf(h)))

proc unimath_complex_bigfloat_destroy(h: pointer) =
  ensureRuntime()
  unrefCxFloat(h)

# ------------------------------------------------------------------------------
# Complex over Rational[BigInt] — handle = pinned `ref Complex[Rational[BigInt]]`.
# The EXACT complex path: `+ - * /`, `conj`, `norm2` and integer powers are
# exact Gaussian-rational arithmetic, unbounded. `abs` and `sqrt` are the only
# approximate entries (they take a root, which leaves the field); no exp/ln/
# sin/cos here, since each would compound two truncated rational series per
# component -- use the BigFloat complex above for transcendentals.
# Never raises: NULL in -> NULL out.
# ------------------------------------------------------------------------------

proc unimath_complex_rational_from_rational(re, im: pointer): pointer =
  ## Builds from two Rational handles, which the caller still owns.
  ensureRuntime()
  if re == nil or im == nil: return nil
  pinCxRat(complex(ratOf(re), ratOf(im)))

proc unimath_complex_rational_from_i64(re_num, re_den, im_num,
                                       im_den: int64): pointer =
  ## NULL if either denominator is zero.
  ensureRuntime()
  if re_den == 0 or im_den == 0: return nil
  pinCxRat(complex(initRational(initBigInt(re_num), initBigInt(re_den)),
                   initRational(initBigInt(im_num), initBigInt(im_den))))

proc unimath_complex_rational_re(h: pointer): pointer =
  ## A NEW Rational handle for the real part; destroy it separately.
  ensureRuntime()
  if h == nil: return nil
  pinRational(cxrOf(h).re)

proc unimath_complex_rational_im(h: pointer): pointer =
  ensureRuntime()
  if h == nil: return nil
  pinRational(cxrOf(h).im)

proc unimath_complex_rational_is_zero(h: pointer): cint =
  ensureRuntime()
  if h == nil: return 0
  cint(cxrOf(h).isZero)

proc unimath_complex_rational_add(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinCxRat(cxrOf(a) + cxrOf(b))

proc unimath_complex_rational_sub(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinCxRat(cxrOf(a) - cxrOf(b))

proc unimath_complex_rational_mul(a, b: pointer): pointer =
  ensureRuntime()
  if a == nil or b == nil: return nil
  pinCxRat(cxrOf(a) * cxrOf(b))

proc unimath_complex_rational_div(a, b: pointer): pointer =
  ## Exact. NULL on a zero divisor.
  ensureRuntime()
  if a == nil or b == nil or cxrOf(b).isZero: return nil
  pinCxRat(cxrOf(a) / cxrOf(b))

proc unimath_complex_rational_neg(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinCxRat(-cxrOf(a))

proc unimath_complex_rational_conj(a: pointer): pointer =
  ensureRuntime()
  if a == nil: return nil
  pinCxRat(conj(cxrOf(a)))

proc unimath_complex_rational_inv(a: pointer): pointer =
  ensureRuntime()
  if a == nil or cxrOf(a).isZero: return nil
  pinCxRat(inv(cxrOf(a)))

proc unimath_complex_rational_norm2(a: pointer): pointer =
  ## EXACT squared modulus as a NEW Rational handle.
  ensureRuntime()
  if a == nil: return nil
  pinRational(norm2(cxrOf(a)))

proc unimath_complex_rational_abs(a: pointer): pointer =
  ## APPROXIMATE modulus as a NEW Rational handle: a square root generally
  ## leaves the rationals, so this is the Newton iterate, not the exact value.
  ensureRuntime()
  if a == nil: return nil
  pinRational(abs(cxrOf(a)))

proc unimath_complex_rational_sqrt(a: pointer): pointer =
  ## APPROXIMATE principal square root — see `unimath_complex_rational_abs`.
  ensureRuntime()
  if a == nil: return nil
  pinCxRat(sqrt(cxrOf(a)))

proc unimath_complex_rational_pow_int(a: pointer; n: cint): pointer =
  ## EXACT integer power. NULL on a negative `n` with a zero base.
  ensureRuntime()
  if a == nil: return nil
  if n < 0 and cxrOf(a).isZero: return nil
  pinCxRat(pow(cxrOf(a), int(n)))

proc unimath_csqrt_rational(h: pointer): pointer =
  ## Square root of a REAL Rational as a complex handle. Approximate in
  ## magnitude, exact in which axis it lands on -- a negative input yields a
  ## purely imaginary result.
  ensureRuntime()
  if h == nil: return nil
  pinCxRat(csqrt(ratOf(h)))

proc unimath_complex_rational_destroy(h: pointer) =
  ensureRuntime()
  unrefCxRat(h)

# ------------------------------------------------------------------------------
# Complex over Fixed — two raw Q-format words, by value, like the Fixed
# scalars. `frac_bits` is the shared fractional width of both components.
# add/sub/neg/conj are scale-invariant; mul/div/norm2/pow take `frac_bits`.
# `abs` and `sqrt` are Q32.32 only, matching `unimath_fixed_sqrt`.
#
# Never raises: results clamp to the int64 range through an exact BigInt
# intermediate, and division by zero returns the zero complex.
# ------------------------------------------------------------------------------

proc unimath_complex_fixed_from_int(re, im: int64;
    frac_bits: cint): ComplexFixedC =
  ensureRuntime()
  ComplexFixedC(re: unimath_fixed_from_int(re, frac_bits),
                im: unimath_fixed_from_int(im, frac_bits))

proc unimath_complex_fixed_re(z: ComplexFixedC): int64 =
  ensureRuntime()
  z.re
proc unimath_complex_fixed_im(z: ComplexFixedC): int64 =
  ensureRuntime()
  z.im

proc unimath_complex_fixed_add(a, b: ComplexFixedC): ComplexFixedC =
  ensureRuntime()
  ComplexFixedC(re: unimath_fixed_add(a.re, b.re),
                im: unimath_fixed_add(a.im, b.im))

proc unimath_complex_fixed_sub(a, b: ComplexFixedC): ComplexFixedC =
  ensureRuntime()
  ComplexFixedC(re: unimath_fixed_sub(a.re, b.re),
                im: unimath_fixed_sub(a.im, b.im))

proc unimath_complex_fixed_neg(a: ComplexFixedC): ComplexFixedC =
  ensureRuntime()
  ComplexFixedC(re: unimath_fixed_sub(0, a.re),
                im: unimath_fixed_sub(0, a.im))

proc unimath_complex_fixed_conj(a: ComplexFixedC): ComplexFixedC =
  ensureRuntime()
  ComplexFixedC(re: a.re, im: unimath_fixed_sub(0, a.im))

proc unimath_complex_fixed_mul(a, b: ComplexFixedC;
                               frac_bits: cint): ComplexFixedC =
  ## `(ac - bd) >> f`, `(ad + bc) >> f`. The products are formed as exact
  ## BigInts before the shift, so no intermediate overflows on the way to a
  ## representable result.
  ensureRuntime()
  if frac_bits < 0 or frac_bits > MaxFracBits:
    return ComplexFixedC(re: 0, im: 0)
  let f = Natural(int(frac_bits))
  let ar = initBigInt(a.re)
  let ai = initBigInt(a.im)
  let br = initBigInt(b.re)
  let bi = initBigInt(b.im)
  ComplexFixedC(re: clampToInt64((ar * br - ai * bi) shr f),
                im: clampToInt64((ar * bi + ai * br) shr f))

proc unimath_complex_fixed_div(a, b: ComplexFixedC;
                               frac_bits: cint): ComplexFixedC =
  ## The textbook quotient over an exact BigInt denominator — no Smith scaling
  ## needed, since `c^2 + d^2` cannot overflow a BigInt. The zero complex on a
  ## zero divisor.
  ensureRuntime()
  if frac_bits < 0 or frac_bits > MaxFracBits:
    return ComplexFixedC(re: 0, im: 0)
  if b.re == 0 and b.im == 0:
    return ComplexFixedC(re: 0, im: 0)
  let f = Natural(int(frac_bits))
  let ar = initBigInt(a.re)
  let ai = initBigInt(a.im)
  let br = initBigInt(b.re)
  let bi = initBigInt(b.im)
  let den = br * br + bi * bi
  ComplexFixedC(re: clampToInt64(((ar * br + ai * bi) shl f) div den),
                im: clampToInt64(((ai * br - ar * bi) shl f) div den))

proc unimath_complex_fixed_norm2(a: ComplexFixedC; frac_bits: cint): int64 =
  ## `(re^2 + im^2) >> f`, clamped.
  ensureRuntime()
  if frac_bits < 0 or frac_bits > MaxFracBits: return 0
  let ar = initBigInt(a.re)
  let ai = initBigInt(a.im)
  clampToInt64((ar * ar + ai * ai) shr Natural(int(frac_bits)))

proc unimath_complex_fixed_abs(a: ComplexFixedC): int64 =
  ## Q32.32 modulus, matching `unimath_fixed_sqrt`'s fixed scale. Zero where
  ## the fixed-point core overflows, as the scalar entry points are.
  ensureRuntime()
  try: abs(complex(fxOf(a.re), fxOf(a.im))).data
  except CatchableError, Defect: 0

proc unimath_complex_fixed_arg(a: ComplexFixedC): int64 =
  ## Q32.32 principal argument, via the CORDIC `atan2`.
  ensureRuntime()
  try: arg(complex(fxOf(a.re), fxOf(a.im))).data
  except CatchableError, Defect: 0

proc unimath_complex_fixed_sqrt(a: ComplexFixedC): ComplexFixedC =
  ## Q32.32 principal square root.
  ensureRuntime()
  try:
    let r = sqrt(complex(fxOf(a.re), fxOf(a.im)))
    ComplexFixedC(re: r.re.data, im: r.im.data)
  except CatchableError, Defect:
    ComplexFixedC(re: 0, im: 0)

proc unimath_complex_fixed_pow_int(a: ComplexFixedC; n: cint;
                                   frac_bits: cint): ComplexFixedC =
  ## Binary exponentiation over the raw words. `n == 0` is 1; a negative `n`
  ## inverts at the end, and a zero base then yields the zero complex.
  ensureRuntime()
  if frac_bits < 0 or frac_bits > MaxFracBits:
    return ComplexFixedC(re: 0, im: 0)
  let one = ComplexFixedC(re: unimath_fixed_from_int(1, frac_bits), im: 0)
  if n == 0: return one
  var base = a
  var k = if n < 0: -int(n) else: int(n)
  var acc = one
  while k > 0:
    if (k and 1) == 1:
      acc = unimath_complex_fixed_mul(acc, base, frac_bits)
    base = unimath_complex_fixed_mul(base, base, frac_bits)
    k = k shr 1
  if n < 0:
    return unimath_complex_fixed_div(one, acc, frac_bits)
  acc

proc unimath_csqrt_fixed(q: int64): ComplexFixedC =
  ## Square root of a REAL Q32.32 value, returned as a complex instead of
  ## clamping a negative input to zero.
  ensureRuntime()
  try:
    let r = csqrt(fxOf(q))
    ComplexFixedC(re: r.re.data, im: r.im.data)
  except CatchableError, Defect:
    ComplexFixedC(re: 0, im: 0)

{.pop.}
