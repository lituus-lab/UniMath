# cython: language_level=3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Cython extension over the UniMath C ABI. The C host owns GC-pinned handles;
this wrapper frees them in __dealloc__. Callers must have run unimath_init()
once per process — done lazily on import via _ensure_init()."""
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from libc.stdint cimport int64_t

cdef extern from "UniMath.h":
    const char *unimath_version()
    int unimath_init()
    void unimath_cleanup()

    ctypedef void *unimath_bigint

    unimath_bigint unimath_bigint_from_i64(long long v)
    unimath_bigint unimath_bigint_from_decimal(const char *s)
    int unimath_bigint_to_decimal(unimath_bigint h, char *buf, size_t size)
    unimath_bigint unimath_bigint_add(unimath_bigint a, unimath_bigint b)
    unimath_bigint unimath_bigint_sub(unimath_bigint a, unimath_bigint b)
    unimath_bigint unimath_bigint_mul(unimath_bigint a, unimath_bigint b)
    unimath_bigint unimath_bigint_div(unimath_bigint a, unimath_bigint b)
    unimath_bigint unimath_bigint_mod(unimath_bigint a, unimath_bigint b)
    unimath_bigint unimath_bigint_neg(unimath_bigint a)
    unimath_bigint unimath_bigint_abs(unimath_bigint a)
    int unimath_bigint_cmp(unimath_bigint a, unimath_bigint b)
    long long unimath_bigint_to_i64(unimath_bigint h, int *out_ok)
    void unimath_bigint_destroy(unimath_bigint h)

    long long unimath_fixed_from_int(long long val, int frac_bits)
    long long unimath_fixed_to_int(long long q, int frac_bits)
    long long unimath_fixed_add(long long a, long long b)
    long long unimath_fixed_sub(long long a, long long b)
    long long unimath_fixed_mul(long long a, long long b, int frac_bits)
    long long unimath_fixed_div(long long a, long long b, int frac_bits)

    ctypedef void *unimath_bigfloat

    unimath_bigfloat unimath_bigfloat_from_f64(double v)
    unimath_bigfloat unimath_bigfloat_from_i64(long long v)
    double unimath_bigfloat_to_f64(unimath_bigfloat h)
    unimath_bigfloat unimath_bigfloat_add(unimath_bigfloat a, unimath_bigfloat b)
    unimath_bigfloat unimath_bigfloat_sub(unimath_bigfloat a, unimath_bigfloat b)
    unimath_bigfloat unimath_bigfloat_mul(unimath_bigfloat a, unimath_bigfloat b)
    unimath_bigfloat unimath_bigfloat_div(unimath_bigfloat a, unimath_bigfloat b)
    int unimath_bigfloat_cmp(unimath_bigfloat a, unimath_bigfloat b)
    void unimath_bigfloat_destroy(unimath_bigfloat h)

    ctypedef void *unimath_rational

    unimath_rational unimath_rational_from_i64(long long num, long long den)
    unimath_rational unimath_rational_from_bigint(unimath_bigint num,
                                                  unimath_bigint den)
    double unimath_rational_to_f64(unimath_rational h)
    unimath_bigint unimath_rational_num(unimath_rational h)
    unimath_bigint unimath_rational_den(unimath_rational h)
    unimath_rational unimath_rational_add(unimath_rational a, unimath_rational b)
    unimath_rational unimath_rational_sub(unimath_rational a, unimath_rational b)
    unimath_rational unimath_rational_mul(unimath_rational a, unimath_rational b)
    unimath_rational unimath_rational_div(unimath_rational a, unimath_rational b)
    unimath_rational unimath_rational_neg(unimath_rational a)
    unimath_rational unimath_rational_abs(unimath_rational a)
    int unimath_rational_cmp(unimath_rational a, unimath_rational b)
    void unimath_rational_destroy(unimath_rational h)

    ctypedef struct unimath_interval:
        double lo
        double hi

    unimath_interval unimath_interval_from_f64(double lo, double hi)
    double unimath_interval_lo(unimath_interval a)
    double unimath_interval_hi(unimath_interval a)
    unimath_interval unimath_interval_add(unimath_interval a, unimath_interval b)
    unimath_interval unimath_interval_sub(unimath_interval a, unimath_interval b)
    unimath_interval unimath_interval_mul(unimath_interval a, unimath_interval b)
    unimath_interval unimath_interval_div(unimath_interval a, unimath_interval b)
    unimath_interval unimath_interval_sqrt(unimath_interval a)
    unimath_interval unimath_interval_exp(unimath_interval a)
    unimath_interval unimath_interval_ln(unimath_interval a)
    unimath_interval unimath_interval_sin(unimath_interval a)
    unimath_interval unimath_interval_cos(unimath_interval a)

    long long unimath_isqrt_i64(long long n)
    double unimath_sqrt_newton_f64(double x)
    unimath_bigfloat unimath_sqrt_newton_bigfloat(unimath_bigfloat h)

    double unimath_exp_taylor_f64(double x)
    double unimath_ln_taylor_f64(double x)
    double unimath_ln_generic_f64(double z)
    unimath_bigfloat unimath_exp_taylor_bigfloat(unimath_bigfloat h)
    unimath_bigfloat unimath_ln_generic_bigfloat(unimath_bigfloat h)

    double unimath_taylor_sin_f64(double x)
    double unimath_taylor_cos_f64(double x)
    double unimath_taylor_atan_f64(double x)
    long long unimath_cordic_sin(long long q)
    long long unimath_cordic_cos(long long q)
    long long unimath_cordic_atan2(long long y, long long x)
    long long unimath_lut_sin(long long q)
    long long unimath_lut_cos(long long q)
    long long unimath_chebyshev_tan(long long q)

    long long unimath_cordic_sinh(long long q)
    long long unimath_cordic_cosh(long long q)
    long long unimath_cordic_tanh(long long q)
    long long unimath_cordic_exp(long long q)

    double unimath_chebyshev_t(int n, double x)
    double unimath_chebyshev_u(int n, double x)
    double unimath_legendre(int n, double x)
    double unimath_hermite(int n, double x)
    double unimath_erf(double x)
    double unimath_gamma(double x)
    double unimath_factorial(int n)
    double unimath_bessel_j0(double x)

    # Handle-returning constants: typed as unimath_bigfloat so the result feeds
    # to_f64/destroy without a cast.
    unimath_bigfloat unimath_pi_bigfloat()
    unimath_bigfloat unimath_e_bigfloat()
    long long unimath_pi_fixed()
    long long unimath_e_fixed()

    unimath_bigfloat unimath_bigfloat_reduce(unimath_bigfloat h)

    # float_math — range-reduced BigFloat transcendentals (handle in/out).
    unimath_bigfloat unimath_bigfloat_sin(unimath_bigfloat h)
    unimath_bigfloat unimath_bigfloat_cos(unimath_bigfloat h)
    unimath_bigfloat unimath_bigfloat_tan(unimath_bigfloat h)
    unimath_bigfloat unimath_bigfloat_exp(unimath_bigfloat h)
    unimath_bigfloat unimath_bigfloat_ln(unimath_bigfloat h)
    unimath_bigfloat unimath_bigfloat_sqrt(unimath_bigfloat h)
    unimath_bigfloat unimath_bigfloat_arctan(unimath_bigfloat h)
    unimath_bigfloat unimath_bigfloat_arctan2(unimath_bigfloat y, unimath_bigfloat x)
    unimath_bigfloat unimath_bigfloat_pow_int(unimath_bigfloat h, int n)
    unimath_bigfloat unimath_bigfloat_pow(unimath_bigfloat h, unimath_bigfloat e)

    unimath_rational unimath_rational_sin(unimath_rational h)
    unimath_rational unimath_rational_cos(unimath_rational h)
    unimath_rational unimath_rational_tan(unimath_rational h)
    unimath_rational unimath_rational_exp(unimath_rational h)
    unimath_rational unimath_rational_ln(unimath_rational h)
    unimath_rational unimath_rational_sqrt(unimath_rational h)
    unimath_rational unimath_rational_atan(unimath_rational h)
    unimath_rational unimath_rational_atan2(unimath_rational y, unimath_rational x)
    unimath_rational unimath_rational_pow(unimath_rational h, unimath_rational e)

    long long unimath_fixed_sin(long long q)
    long long unimath_fixed_cos(long long q)
    long long unimath_fixed_tan(long long q)
    long long unimath_fixed_exp(long long q)
    long long unimath_fixed_ln(long long q)
    long long unimath_fixed_sqrt(long long q)
    long long unimath_fixed_atan(long long q)
    long long unimath_fixed_atan2(long long y, long long x)
    long long unimath_fixed_sinh(long long q)
    long long unimath_fixed_cosh(long long q)
    long long unimath_fixed_tanh(long long q)
    long long unimath_fixed_pow(long long base, long long exponent)

    # ---- conversions ----
    unimath_rational unimath_rational_from_f64(double v)
    unimath_rational unimath_rational_from_fixed(long long q, int frac_bits)
    unimath_bigfloat unimath_bigfloat_from_rational(unimath_rational h)
    unimath_bigint unimath_bigint_from_bigfloat(unimath_bigfloat h)
    unimath_bigint unimath_bigint_from_rational(unimath_rational h)
    long long unimath_fixed_from_rational(unimath_rational h, int frac_bits)
    unimath_interval unimath_interval_from_bigfloat(unimath_bigfloat h)
    unimath_interval unimath_interval_from_rational(unimath_rational h)
    unimath_interval unimath_interval_from_bigint(unimath_bigint h)


# Unary BigFloat transcendental (handle in, handle out) — the FloatMath._unary
# helper dispatches over this signature.
ctypedef unimath_bigfloat (*unimath_bf_unary)(unimath_bigfloat)

# Unary Rational transcendental (handle in, handle out) — the
# RationalMath._unary helper dispatches over this signature.
ctypedef unimath_rational (*unimath_rat_unary)(unimath_rational)

# Unary Q32.32 fixed transcendental (raw word in, raw word out) — the
# MathRouter._unary helper dispatches over this signature.
ctypedef long long (*unimath_fix_unary)(long long)


cdef int _inited = 0

cdef inline _ensure_init():
    global _inited
    if not _inited:
        unimath_init()
        _inited = 1


def version():
    return unimath_version()


cdef _decimal(unimath_bigint h):
    """Read a BigInt's decimal into a Python str. Grows the buffer until it fits."""
    cdef size_t cap = 64
    cdef char *buf
    cdef int n
    while True:
        buf = <char *>malloc(cap)
        if buf == NULL:
            raise MemoryError()
        n = unimath_bigint_to_decimal(h, buf, cap)
        if n >= 0:
            try:
                return buf[:n].decode("ascii")
            finally:
                free(buf)
        free(buf)
        if cap > (1 << 24):
            raise MemoryError("BigInt decimal exceeds 16 MiB")
        cap *= 2


cdef class BigInt:
    """Arbitrary-precision signed integer over the UniMath C ABI."""
    cdef unimath_bigint _h

    def __cinit__(self):
        self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            unimath_bigint_destroy(self._h)
            self._h = NULL

    cdef unimath_bigint _take(self):
        """Hand ownership of the handle to the C ABI (a new pinned ref)."""
        cdef unimath_bigint h = self._h
        self._h = NULL
        return h

    @staticmethod
    cdef BigInt _wrap(unimath_bigint h):
        cdef BigInt r = BigInt.__new__(BigInt)
        r._h = h
        return r

    def __init__(self, value):
        _ensure_init()
        if self._h != NULL:
            unimath_bigint_destroy(self._h)
            self._h = NULL
        if isinstance(value, BigInt):
            self._h = unimath_bigint_from_decimal((<str>str(value)).encode("ascii"))
        elif isinstance(value, int):
            self._h = unimath_bigint_from_decimal(str(value).encode("ascii"))
        else:
            raise TypeError("BigInt expects an int or BigInt, got " + type(value).__name__)
        if self._h == NULL:
            raise ValueError("BigInt construction failed (bad input)")

    def __str__(self):
        if self._h == NULL:
            return "0"
        return _decimal(self._h)

    def __repr__(self):
        return "BigInt(" + str(self) + ")"

    def __add__(self, other):
        cdef BigInt o = _coerce(other)
        return BigInt._wrap(unimath_bigint_add(self._h, o._h))

    def __sub__(self, other):
        cdef BigInt o = _coerce(other)
        return BigInt._wrap(unimath_bigint_sub(self._h, o._h))

    def __mul__(self, other):
        cdef BigInt o = _coerce(other)
        return BigInt._wrap(unimath_bigint_mul(self._h, o._h))

    def __floordiv__(self, other):
        cdef BigInt o = _coerce(other)
        cdef unimath_bigint r = unimath_bigint_div(self._h, o._h)
        if r == NULL:
            raise ZeroDivisionError("BigInt division by zero")
        return BigInt._wrap(r)

    def __mod__(self, other):
        cdef BigInt o = _coerce(other)
        cdef unimath_bigint r = unimath_bigint_mod(self._h, o._h)
        if r == NULL:
            raise ZeroDivisionError("BigInt modulo by zero")
        return BigInt._wrap(r)

    # Reflected numeric operators: `int + BigInt`, `int - BigInt`, ... Python
    # calls these when the left operand (e.g. int) returns NotImplemented. Add
    # and mul commute, so they delegate to the left-hand form; sub/floordiv/mod
    # compute `other OP self` through the same coercion + C ABI calls.

    def __radd__(self, other):
        return self + other

    def __rsub__(self, other):
        cdef BigInt o = _coerce(other)
        return BigInt._wrap(unimath_bigint_sub(o._h, self._h))

    def __rmul__(self, other):
        return self * other

    def __rfloordiv__(self, other):
        cdef BigInt o = _coerce(other)
        cdef unimath_bigint r = unimath_bigint_div(o._h, self._h)
        if r == NULL:
            raise ZeroDivisionError("BigInt division by zero")
        return BigInt._wrap(r)

    def __rmod__(self, other):
        cdef BigInt o = _coerce(other)
        cdef unimath_bigint r = unimath_bigint_mod(o._h, self._h)
        if r == NULL:
            raise ZeroDivisionError("BigInt modulo by zero")
        return BigInt._wrap(r)

    def __neg__(self):
        return BigInt._wrap(unimath_bigint_neg(self._h))

    def __abs__(self):
        return BigInt._wrap(unimath_bigint_abs(self._h))

    def __eq__(self, other):
        cdef BigInt o
        try:
            o = _coerce(other)
        except TypeError:
            return NotImplemented
        return unimath_bigint_cmp(self._h, o._h) == 0

    def __ne__(self, other):
        cdef BigInt o
        try:
            o = _coerce(other)
        except TypeError:
            return NotImplemented
        return unimath_bigint_cmp(self._h, o._h) != 0

    def __lt__(self, other):
        cdef BigInt o = _coerce(other)
        return unimath_bigint_cmp(self._h, o._h) < 0

    def __le__(self, other):
        cdef BigInt o = _coerce(other)
        return unimath_bigint_cmp(self._h, o._h) <= 0

    def __gt__(self, other):
        cdef BigInt o = _coerce(other)
        return unimath_bigint_cmp(self._h, o._h) > 0

    def __ge__(self, other):
        cdef BigInt o = _coerce(other)
        return unimath_bigint_cmp(self._h, o._h) >= 0

    def __hash__(self):
        # Match the hash of the equal native int so the a==b => hash(a)==hash(b)
        # invariant holds: BigInt(7) == 7 must hash like 7 (str(self) would hash
        # the string "7"). str(self) is the decimal; int(...) parses the exact
        # Python int (arbitrary width).
        return hash(int(str(self)))

    def to_i64(self):
        """Best-effort int64, clamped to the int64 range. Returns (value, ok)."""
        cdef int ok = 2
        cdef long long v = unimath_bigint_to_i64(self._h, &ok)
        return int(v), bool(ok)


cdef BigInt _coerce(value):
    if isinstance(value, BigInt):
        return value
    return BigInt(value)


cdef class Fixed:
    """Fixed-point Q-format value over the UniMath C ABI. Stores the raw int64
    `data` (scaled by 2^frac_bits) and the fractional width. Arithmetic goes
    through the C ABI (exact BigInt intermediate, clamped to int64); the C ABI
    has no float entry, so float construction scales in Python."""
    cdef long long _raw
    cdef int _frac

    def __init__(self, value, int frac_bits=16):
        _ensure_init()
        self._frac = frac_bits
        if isinstance(value, Fixed):
            if (<Fixed>value)._frac != frac_bits:
                raise ValueError("frac_bits mismatch in copy")
            self._raw = (<Fixed>value)._raw
        elif isinstance(value, int):
            self._raw = unimath_fixed_from_int(<long long>value, frac_bits)
        elif isinstance(value, float):
            self._raw = <long long>int(value * (<long long>1 << frac_bits))
        else:
            raise TypeError("Fixed expects an int, float, or Fixed, got " + type(value).__name__)

    @staticmethod
    cdef Fixed _from_raw(long long raw, int frac_bits):
        cdef Fixed r = Fixed.__new__(Fixed)
        r._raw = raw
        r._frac = frac_bits
        return r

    def raw(self):
        """The raw int64 data."""
        return int(self._raw)

    def frac_bits(self):
        return self._frac

    def to_int(self):
        """Integer part (arithmetic shift)."""
        return int(unimath_fixed_to_int(self._raw, self._frac))

    def value(self):
        """Real value as a Python float (may lose precision past 53 bits)."""
        return float(self._raw) / float(<long long>1 << self._frac)

    def __str__(self):
        return str(self.value())

    def __repr__(self):
        return "Fixed(" + str(self.value()) + ", frac_bits=" + str(self._frac) + ")"

    cdef Fixed _bin(self, long long raw, int frac_bits):
        return Fixed._from_raw(raw, frac_bits)

    def __add__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._bin(unimath_fixed_add(self._raw, o._raw), self._frac)

    def __sub__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._bin(unimath_fixed_sub(self._raw, o._raw), self._frac)

    def __mul__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._bin(unimath_fixed_mul(self._raw, o._raw, self._frac), self._frac)

    def __floordiv__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._bin(unimath_fixed_div(self._raw, o._raw, self._frac), self._frac)

    # Reflected numeric operators (see BigInt): `int + Fixed`, etc. Add and mul
    # commute; sub/floordiv compute `other OP self` at self's frac_bits.

    def __radd__(self, other):
        return self + other

    def __rsub__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._bin(unimath_fixed_sub(o._raw, self._raw), self._frac)

    def __rmul__(self, other):
        return self * other

    def __rfloordiv__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._bin(unimath_fixed_div(o._raw, self._raw, self._frac), self._frac)

    def __eq__(self, other):
        cdef Fixed o
        try:
            o = _coerce_fixed(other, self._frac)
        except TypeError:
            return NotImplemented
        return self._raw == o._raw

    def __ne__(self, other):
        cdef Fixed o
        try:
            o = _coerce_fixed(other, self._frac)
        except TypeError:
            return NotImplemented
        return self._raw != o._raw

    def __lt__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._raw < o._raw

    def __le__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._raw <= o._raw

    def __gt__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._raw > o._raw

    def __ge__(self, other):
        cdef Fixed o = _coerce_fixed(other, self._frac)
        return self._raw >= o._raw

    def __hash__(self):
        # Hash the represented value (a float) so Fixed(2, 16) == 2 and
        # == 2.0 all hash alike (a==b => hash(a)==hash(b)). The raw tuple
        # (self._raw, self._frac) never matches an int/float hash.
        return hash(self.value())


cdef Fixed _coerce_fixed(value, int frac_bits):
    if isinstance(value, Fixed):
        if (<Fixed>value)._frac != frac_bits:
            raise ValueError("frac_bits mismatch")
        return value
    return Fixed(value, frac_bits)


cdef class BigFloat:
    """Arbitrary-precision float over the UniMath C ABI (default 256-bit
    precision). The C host owns the GC-pinned handle; freed in __dealloc__."""
    cdef unimath_bigfloat _h

    def __cinit__(self):
        self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            unimath_bigfloat_destroy(self._h)
            self._h = NULL

    @staticmethod
    cdef BigFloat _wrap(unimath_bigfloat h):
        cdef BigFloat r = BigFloat.__new__(BigFloat)
        r._h = h
        return r

    def __init__(self, value):
        _ensure_init()
        cdef unimath_bigfloat _zero
        if self._h != NULL:
            unimath_bigfloat_destroy(self._h)
            self._h = NULL
        if isinstance(value, BigFloat):
            # Preserve full precision: copy via an exact +0 (a new owned handle)
            # rather than a float64 round-trip that truncates to 53 bits.
            _zero = unimath_bigfloat_from_f64(0.0)
            self._h = unimath_bigfloat_add((<BigFloat>value)._h, _zero)
            unimath_bigfloat_destroy(_zero)
        elif isinstance(value, int):
            self._h = unimath_bigfloat_from_i64(<long long>value)
        elif isinstance(value, float):
            if value != value or value in (float("inf"), float("-inf")):
                raise ValueError("BigFloat cannot represent Inf or NaN")
            self._h = unimath_bigfloat_from_f64(<double>value)
        else:
            raise TypeError("BigFloat expects an int or float, got " + type(value).__name__)
        if self._h == NULL:
            raise ValueError("BigFloat construction failed (bad input)")

    def to_f64(self):
        """Correctly-rounded float64 (±Inf on overflow, ±0 on underflow)."""
        return float(unimath_bigfloat_to_f64(self._h))

    def __float__(self):
        return self.to_f64()

    def __str__(self):
        return str(self.to_f64())

    def __repr__(self):
        return "BigFloat(" + str(self.to_f64()) + ")"

    def __add__(self, other):
        cdef BigFloat o = _coerce_bigfloat(other)
        return BigFloat._wrap(unimath_bigfloat_add(self._h, o._h))

    def __sub__(self, other):
        cdef BigFloat o = _coerce_bigfloat(other)
        return BigFloat._wrap(unimath_bigfloat_sub(self._h, o._h))

    def __mul__(self, other):
        cdef BigFloat o = _coerce_bigfloat(other)
        return BigFloat._wrap(unimath_bigfloat_mul(self._h, o._h))

    def __truediv__(self, other):
        cdef BigFloat o = _coerce_bigfloat(other)
        cdef unimath_bigfloat r = unimath_bigfloat_div(self._h, o._h)
        if r == NULL:
            raise ZeroDivisionError("BigFloat division by zero")
        return BigFloat._wrap(r)

    def __neg__(self):
        cdef BigFloat z = BigFloat._wrap(unimath_bigfloat_from_f64(0.0))
        return BigFloat._wrap(unimath_bigfloat_sub(z._h, self._h))

    def __eq__(self, other):
        cdef BigFloat o
        try:
            o = _coerce_bigfloat(other)
        except TypeError:
            return NotImplemented
        return unimath_bigfloat_cmp(self._h, o._h) == 0

    def __ne__(self, other):
        cdef BigFloat o
        try:
            o = _coerce_bigfloat(other)
        except TypeError:
            return NotImplemented
        return unimath_bigfloat_cmp(self._h, o._h) != 0

    def __lt__(self, other):
        cdef BigFloat o = _coerce_bigfloat(other)
        return unimath_bigfloat_cmp(self._h, o._h) < 0

    def __le__(self, other):
        cdef BigFloat o = _coerce_bigfloat(other)
        return unimath_bigfloat_cmp(self._h, o._h) <= 0

    def __gt__(self, other):
        cdef BigFloat o = _coerce_bigfloat(other)
        return unimath_bigfloat_cmp(self._h, o._h) > 0

    def __ge__(self, other):
        cdef BigFloat o = _coerce_bigfloat(other)
        return unimath_bigfloat_cmp(self._h, o._h) >= 0

    def __hash__(self):
        return hash(self.to_f64())


cdef BigFloat _coerce_bigfloat(value):
    if isinstance(value, BigFloat):
        return value
    return BigFloat(value)


cdef class Rational:
    """Exact rational over the UniMath C ABI (unbounded Rational[BigInt]). The
    C host owns the GC-pinned handle; freed in __dealloc__. Constructed from an
    integer `n` (-> n/1) or a `(num, den)` pair of ints."""
    cdef unimath_rational _h

    def __cinit__(self):
        self._h = NULL

    def __dealloc__(self):
        if self._h != NULL:
            unimath_rational_destroy(self._h)
            self._h = NULL

    @staticmethod
    cdef Rational _wrap(unimath_rational h):
        cdef Rational r = Rational.__new__(Rational)
        r._h = h
        return r

    def __init__(self, num, den=None):
        cdef Rational o
        cdef unimath_bigint hn, hd
        _ensure_init()
        if self._h != NULL:
            unimath_rational_destroy(self._h)
            self._h = NULL
        if isinstance(num, Rational):
            # exact copy through the BigInt num/den accessors (no float
            # detour). num/den return fresh caller-owned handles; destroy them
            # after from_bigint copies their values (or they leak).
            o = num
            hn = unimath_rational_num(o._h)
            hd = unimath_rational_den(o._h)
            self._h = unimath_rational_from_bigint(hn, hd)
            unimath_bigint_destroy(hn)
            unimath_bigint_destroy(hd)
        else:
            if den is None:
                den = 1
            if not isinstance(num, int) or not isinstance(den, int):
                raise TypeError("Rational expects ints (num, den), got " +
                                type(num).__name__ + ", " + type(den).__name__)
            self._h = unimath_rational_from_i64(<long long>num, <long long>den)
        if self._h == NULL:
            raise ZeroDivisionError("Rational denominator cannot be zero")

    def numerator(self):
        """Numerator as a BigInt (exact)."""
        return BigInt._wrap(unimath_rational_num(self._h))

    def denominator(self):
        """Denominator as a BigInt (exact)."""
        return BigInt._wrap(unimath_rational_den(self._h))

    def to_f64(self):
        """Approximate float64 (rounded division)."""
        return float(unimath_rational_to_f64(self._h))

    def __float__(self):
        return self.to_f64()

    def __str__(self):
        return str(self.numerator()) + "/" + str(self.denominator())

    def __repr__(self):
        return "Rational(" + str(self.numerator()) + ", " + \
               str(self.denominator()) + ")"

    def __add__(self, other):
        cdef Rational o = _coerce_rational(other)
        return Rational._wrap(unimath_rational_add(self._h, o._h))

    def __sub__(self, other):
        cdef Rational o = _coerce_rational(other)
        return Rational._wrap(unimath_rational_sub(self._h, o._h))

    def __mul__(self, other):
        cdef Rational o = _coerce_rational(other)
        return Rational._wrap(unimath_rational_mul(self._h, o._h))

    def __truediv__(self, other):
        cdef Rational o = _coerce_rational(other)
        cdef unimath_rational r = unimath_rational_div(self._h, o._h)
        if r == NULL:
            raise ZeroDivisionError("Rational division by zero")
        return Rational._wrap(r)

    def __neg__(self):
        return Rational._wrap(unimath_rational_neg(self._h))

    def __abs__(self):
        return Rational._wrap(unimath_rational_abs(self._h))

    def __eq__(self, other):
        cdef Rational o
        try:
            o = _coerce_rational(other)
        except TypeError:
            return NotImplemented
        return unimath_rational_cmp(self._h, o._h) == 0

    def __ne__(self, other):
        cdef Rational o
        try:
            o = _coerce_rational(other)
        except TypeError:
            return NotImplemented
        return unimath_rational_cmp(self._h, o._h) != 0

    def __lt__(self, other):
        cdef Rational o = _coerce_rational(other)
        return unimath_rational_cmp(self._h, o._h) < 0

    def __le__(self, other):
        cdef Rational o = _coerce_rational(other)
        return unimath_rational_cmp(self._h, o._h) <= 0

    def __gt__(self, other):
        cdef Rational o = _coerce_rational(other)
        return unimath_rational_cmp(self._h, o._h) > 0

    def __ge__(self, other):
        cdef Rational o = _coerce_rational(other)
        return unimath_rational_cmp(self._h, o._h) >= 0

    def __hash__(self):
        # `__eq__` coerces an int to a Rational (Rational(2,1) == 2), so the hash
        # must agree with hash(int)/hash(float) of the equal value; to_f64()
        # gives that value and its hash matches the equal int/float.
        return hash(self.to_f64())


cdef Rational _coerce_rational(value):
    if isinstance(value, Rational):
        return value
    return Rational(value)


cdef class Interval:
    """Directed-rounding interval `[lo, hi]` over the UniMath C ABI. A value
    type (two doubles), not a handle: each op goes through the C ABI and reads
    the widened bounds back. The C ABI never raises — a wholly out-of-domain
    op (sqrt/ln of a non-positive interval) yields a NaN interval, and division
    by an interval containing zero yields the unbounded (-Inf, Inf) enclosure."""
    cdef double _lo
    cdef double _hi

    def __init__(self, lo, hi=None):
        _ensure_init()
        if hi is None:
            hi = lo
        self._lo = float(lo)
        self._hi = float(hi)

    @staticmethod
    cdef Interval _wrap(unimath_interval r):
        cdef Interval o = Interval.__new__(Interval)
        o._lo = r.lo
        o._hi = r.hi
        return o

    cdef unimath_interval _c(self):
        return unimath_interval_from_f64(self._lo, self._hi)

    @property
    def lo(self):
        return self._lo

    @property
    def hi(self):
        return self._hi

    def __add__(self, other):
        cdef Interval o = _coerce_interval(other)
        return Interval._wrap(unimath_interval_add(self._c(), o._c()))

    def __sub__(self, other):
        cdef Interval o = _coerce_interval(other)
        return Interval._wrap(unimath_interval_sub(self._c(), o._c()))

    def __mul__(self, other):
        cdef Interval o = _coerce_interval(other)
        return Interval._wrap(unimath_interval_mul(self._c(), o._c()))

    def __truediv__(self, other):
        cdef Interval o = _coerce_interval(other)
        return Interval._wrap(unimath_interval_div(self._c(), o._c()))

    def sqrt(self):
        return Interval._wrap(unimath_interval_sqrt(self._c()))

    def exp(self):
        return Interval._wrap(unimath_interval_exp(self._c()))

    def ln(self):
        return Interval._wrap(unimath_interval_ln(self._c()))

    def sin(self):
        return Interval._wrap(unimath_interval_sin(self._c()))

    def cos(self):
        return Interval._wrap(unimath_interval_cos(self._c()))

    def __eq__(self, other):
        cdef Interval o
        try:
            o = _coerce_interval(other)
        except TypeError:
            return NotImplemented
        return self._lo == o._lo and self._hi == o._hi

    def __ne__(self, other):
        cdef Interval o
        try:
            o = _coerce_interval(other)
        except TypeError:
            return NotImplemented
        return not (self._lo == o._lo and self._hi == o._hi)

    def __hash__(self):
        return hash((self._lo, self._hi))

    def __str__(self):
        return "[" + str(self._lo) + ", " + str(self._hi) + "]"

    def __repr__(self):
        return "Interval(" + str(self._lo) + ", " + str(self._hi) + ")"


cdef Interval _coerce_interval(value):
    if isinstance(value, Interval):
        return value
    return Interval(value)


cdef class Roots:
    """Root extraction over the UniMath C ABI: integer square root and the
    Newton-Raphson square root for float64 and `BigFloat`. The C ABI never
    raises — a negative input clamps to 0 (isqrt) / NaN (float64 sqrt) / NULL
    (BigFloat sqrt, surfaced here as `ValueError`)."""
    @staticmethod
    def isqrt(n):
        """Integer square root of `n` (largest `r` with `r*r <= n`).
        Negative `n` returns 0; out-of-range clamps to the int64 range."""
        _ensure_init()
        return unimath_isqrt_i64(<long long>n)

    @staticmethod
    def sqrt_newton(x):
        """Newton-Raphson square root of a float64. Negative `x` returns NaN."""
        _ensure_init()
        return unimath_sqrt_newton_f64(<double>x)

    @staticmethod
    def sqrt_newton_bigfloat(bf):
        """Newton-Raphson square root of a `BigFloat`. Raises `ValueError` on
        a negative input (the C ABI returns NULL)."""
        _ensure_init()
        cdef BigFloat b
        cdef unimath_bigfloat r
        if isinstance(bf, BigFloat):
            b = bf
        else:
            b = BigFloat(bf)
        r = unimath_sqrt_newton_bigfloat(b._h)
        if r == NULL:
            raise ValueError("sqrt of a negative BigFloat is undefined")
        return BigFloat._wrap(r)


cdef class Exponential:
    """Exponential and logarithm over the UniMath C ABI: Taylor `exp` and
    `ln(1+x)`, and the generic `ln(z)`, for float64 and `BigFloat`. The C ABI
    never raises — an out-of-domain log returns NaN (float64) / NULL (BigFloat,
    surfaced here as `ValueError`)."""
    @staticmethod
    def exp(x):
        """Taylor `exp(x)` of a float64."""
        _ensure_init()
        return unimath_exp_taylor_f64(<double>x)

    @staticmethod
    def ln_1px(x):
        """Taylor `ln(1+x)` of a float64. `x <= -1` returns NaN."""
        _ensure_init()
        return unimath_ln_taylor_f64(<double>x)

    @staticmethod
    def ln(z):
        """Generic `ln(z)` of a positive float64. `z <= 0` returns NaN."""
        _ensure_init()
        return unimath_ln_generic_f64(<double>z)

    @staticmethod
    def exp_bigfloat(bf):
        """Taylor `exp` of a `BigFloat`."""
        _ensure_init()
        cdef BigFloat b
        if isinstance(bf, BigFloat):
            b = bf
        else:
            b = BigFloat(bf)
        return BigFloat._wrap(unimath_exp_taylor_bigfloat(b._h))

    @staticmethod
    def ln_bigfloat(bf):
        """Generic `ln(z)` of a positive `BigFloat`. Raises `ValueError` on
        `z <= 0` (the C ABI returns NULL)."""
        _ensure_init()
        cdef BigFloat b
        cdef unimath_bigfloat r
        if isinstance(bf, BigFloat):
            b = bf
        else:
            b = BigFloat(bf)
        r = unimath_ln_generic_bigfloat(b._h)
        if r == NULL:
            raise ValueError("ln of a non-positive BigFloat is undefined")
        return BigFloat._wrap(r)


cdef double _Q32 = <double>(<long long>1 << 32)

cdef long long _to_q32(double x):
    return <long long>(x * _Q32)

cdef double _from_q32(long long q):
    return <double>q / _Q32


cdef class Trigonometry:
    """Trigonometry over the UniMath C ABI: generic Taylor `sin`/`cos`/`atan`
    (float64), and the fixed-point CORDIC/LUT/Chebyshev cores. The fixed-point
    cores run at Q32.32 internally; this class takes float angles and returns
    float results, hiding the Q-format. The C ABI never raises."""
    @staticmethod
    def sin(x):
        """Taylor `sin(x)` of a float64."""
        _ensure_init()
        return unimath_taylor_sin_f64(<double>x)

    @staticmethod
    def cos(x):
        """Taylor `cos(x)` of a float64."""
        _ensure_init()
        return unimath_taylor_cos_f64(<double>x)

    @staticmethod
    def atan(x):
        """Taylor `atan(x)` of a float64."""
        _ensure_init()
        return unimath_taylor_atan_f64(<double>x)

    def cordic_sin(self, x):
        """CORDIC `sin(x)` (Q32.32 internally)."""
        _ensure_init()
        return _from_q32(unimath_cordic_sin(_to_q32(<double>x)))

    def cordic_cos(self, x):
        """CORDIC `cos(x)` (Q32.32 internally)."""
        _ensure_init()
        return _from_q32(unimath_cordic_cos(_to_q32(<double>x)))

    def cordic_atan2(self, y, x):
        """CORDIC `atan2(y, x)` (Q32.32 internally). The origin returns 0.0."""
        _ensure_init()
        return _from_q32(unimath_cordic_atan2(_to_q32(<double>y),
                                                   _to_q32(<double>x)))

    def lut_sin(self, x):
        """LUT `sin(x)` (Q32.32, nearest-neighbour)."""
        _ensure_init()
        return _from_q32(unimath_lut_sin(_to_q32(<double>x)))

    def lut_cos(self, x):
        """LUT `cos(x)` (Q32.32, nearest-neighbour)."""
        _ensure_init()
        return _from_q32(unimath_lut_cos(_to_q32(<double>x)))

    def chebyshev_tan(self, x):
        """Chebyshev minimax `tan(x)` on `[-pi/4, pi/4]` (Q32.32 internally)."""
        _ensure_init()
        return _from_q32(unimath_chebyshev_tan(_to_q32(<double>x)))


cdef class Hyperbolic:
    """Hyperbolic functions over the UniMath C ABI: fixed-point CORDIC
    `sinh`/`cosh`/`tanh`/`exp` (Q32.32 internally). Hyperbolic CORDIC converges
    only for `|z| <= ~1.1182`; the C ABI clamps the angle to that domain, so it
    never raises — an out-of-domain argument returns the boundary value, not a
    `ValueError`. Use the BigFloat exp/sinh/cosh for larger arguments."""
    def sinh(self, x):
        """CORDIC `sinh(x)` (Q32.32 internally; angle clamped to the domain)."""
        _ensure_init()
        return _from_q32(unimath_cordic_sinh(_to_q32(<double>x)))

    def cosh(self, x):
        """CORDIC `cosh(x)` (Q32.32 internally; angle clamped to the domain)."""
        _ensure_init()
        return _from_q32(unimath_cordic_cosh(_to_q32(<double>x)))

    def tanh(self, x):
        """CORDIC `tanh(x)` (Q32.32 internally; angle clamped to the domain)."""
        _ensure_init()
        return _from_q32(unimath_cordic_tanh(_to_q32(<double>x)))

    def exp(self, x):
        """CORDIC `e^x` (Q32.32 internally; angle clamped to the domain)."""
        _ensure_init()
        return _from_q32(unimath_cordic_exp(_to_q32(<double>x)))


cdef class Special:
    """Special functions over the UniMath C ABI (all float64): the orthogonal
    polynomials (Chebyshev T/U, Legendre, Hermite), the error function, Gamma,
    factorial, and Bessel `J0`. `gamma` returns `nan` at the non-positive-integer
    poles (the Nim core raises there; the C ABI never raises); `factorial`
    returns `0.0` for `n < 0`."""
    def chebyshev_t(self, n, x):
        """Chebyshev polynomial of the first kind `T_n(x)`."""
        _ensure_init()
        return unimath_chebyshev_t(<int>n, <double>x)

    def chebyshev_u(self, n, x):
        """Chebyshev polynomial of the second kind `U_n(x)`."""
        _ensure_init()
        return unimath_chebyshev_u(<int>n, <double>x)

    def legendre(self, n, x):
        """Legendre polynomial `P_n(x)`."""
        _ensure_init()
        return unimath_legendre(<int>n, <double>x)

    def hermite(self, n, x):
        """Hermite polynomial `H_n(x)`."""
        _ensure_init()
        return unimath_hermite(<int>n, <double>x)

    def erf(self, x):
        """Error function `erf(x)` (Taylor series, 15 terms)."""
        _ensure_init()
        return unimath_erf(<double>x)

    def gamma(self, x):
        """`Gamma(x)` (Lanczos g=7, n=9); `nan` at the non-positive-integer poles."""
        _ensure_init()
        return unimath_gamma(<double>x)

    def factorial(self, n):
        """`n!` for non-negative `n` (`0.0` for `n < 0`)."""
        _ensure_init()
        return unimath_factorial(<int>n)

    def bessel_j0(self, x):
        """Bessel `J0(x)` (power series, 15 terms)."""
        _ensure_init()
        return unimath_bessel_j0(<double>x)


cdef class Constants:
    """Mathematical constants over the UniMath C ABI: `pi`/`e` as 256-bit
    BigFloat handles (returned as float64 here, the handle destroyed after
    extraction) and as raw Q32.32 words (returned as float64)."""
    def pi_bigfloat(self):
        """`pi` as a 256-bit BigFloat (Machin's formula), returned as float64."""
        cdef unimath_bigfloat h
        cdef double v
        _ensure_init()
        h = unimath_pi_bigfloat()
        v = unimath_bigfloat_to_f64(h)
        unimath_bigfloat_destroy(h)
        return v

    def e_bigfloat(self):
        """`e` as a 256-bit BigFloat (the `exp(1)` series), returned as float64."""
        cdef unimath_bigfloat h
        cdef double v
        _ensure_init()
        h = unimath_e_bigfloat()
        v = unimath_bigfloat_to_f64(h)
        unimath_bigfloat_destroy(h)
        return v

    def pi_fixed(self):
        """`pi` as a Q32.32 word, returned as float64."""
        _ensure_init()
        return <double>unimath_pi_fixed() / _Q32

    def e_fixed(self):
        """`e` as a Q32.32 word, returned as float64."""
        _ensure_init()
        return <double>unimath_e_fixed() / _Q32


cdef class Reduction:
    """BigFloat trig stage-1 range reduction over the UniMath C ABI: reduces
    `x` mod `2*pi` into `[-pi, pi]` (`r = x - round(x/2pi)·2pi`). The handle is
    destroyed after extraction; the result is returned as float64."""
    def reduce(self, x):
        """Reduce `x` mod `2*pi` into `[-pi, pi]`, returned as float64."""
        cdef unimath_bigfloat h = unimath_bigfloat_from_f64(<double>x)
        cdef unimath_bigfloat r = unimath_bigfloat_reduce(h)
        cdef double v = unimath_bigfloat_to_f64(r)
        unimath_bigfloat_destroy(h)
        unimath_bigfloat_destroy(r)
        return v


cdef class FloatMath:
    """Range-reduced BigFloat transcendentals over the UniMath C ABI. Each
    method builds a BigFloat handle from a float64, calls the C ABI, extracts
    the float64 result, and destroys both handles. Domain errors (ln/pow of a
    non-positive base, sqrt of a negative, tan at a singularity) return
    `None` — the C ABI returns NULL rather than raising."""

    cdef _unary(self, double x, unimath_bf_unary fn):
        cdef unimath_bigfloat h = unimath_bigfloat_from_f64(x)
        cdef unimath_bigfloat r = fn(h)
        cdef double v
        if r == NULL:
            unimath_bigfloat_destroy(h)
            return None
        v = unimath_bigfloat_to_f64(r)
        unimath_bigfloat_destroy(h)
        unimath_bigfloat_destroy(r)
        return v

    def sin(self, x):
        return self._unary(<double>x, unimath_bigfloat_sin)

    def cos(self, x):
        return self._unary(<double>x, unimath_bigfloat_cos)

    def tan(self, x):
        return self._unary(<double>x, unimath_bigfloat_tan)

    def exp(self, x):
        return self._unary(<double>x, unimath_bigfloat_exp)

    def ln(self, x):
        return self._unary(<double>x, unimath_bigfloat_ln)

    def sqrt(self, x):
        return self._unary(<double>x, unimath_bigfloat_sqrt)

    def arctan(self, x):
        return self._unary(<double>x, unimath_bigfloat_arctan)

    def arctan2(self, y, x):
        cdef unimath_bigfloat hy = unimath_bigfloat_from_f64(<double>y)
        cdef unimath_bigfloat hx = unimath_bigfloat_from_f64(<double>x)
        cdef unimath_bigfloat r = unimath_bigfloat_arctan2(hy, hx)
        cdef double v
        if r == NULL:
            unimath_bigfloat_destroy(hy)
            unimath_bigfloat_destroy(hx)
            return None
        v = unimath_bigfloat_to_f64(r)
        unimath_bigfloat_destroy(hy)
        unimath_bigfloat_destroy(hx)
        unimath_bigfloat_destroy(r)
        return v

    def pow(self, x, e):
        cdef unimath_bigfloat hx = unimath_bigfloat_from_f64(<double>x)
        cdef unimath_bigfloat he = unimath_bigfloat_from_f64(<double>e)
        cdef unimath_bigfloat r = unimath_bigfloat_pow(hx, he)
        cdef double v
        if r == NULL:
            unimath_bigfloat_destroy(hx)
            unimath_bigfloat_destroy(he)
            return None
        v = unimath_bigfloat_to_f64(r)
        unimath_bigfloat_destroy(hx)
        unimath_bigfloat_destroy(he)
        unimath_bigfloat_destroy(r)
        return v

    def pow_int(self, x, n):
        cdef unimath_bigfloat h = unimath_bigfloat_from_f64(<double>x)
        cdef unimath_bigfloat r = unimath_bigfloat_pow_int(h, <int>n)
        cdef double v
        if r == NULL:
            unimath_bigfloat_destroy(h)
            return None
        v = unimath_bigfloat_to_f64(r)
        unimath_bigfloat_destroy(h)
        unimath_bigfloat_destroy(r)
        return v

cdef class RationalMath:
    """Rational[BigInt] transcendentals over the UniMath C ABI (exact per term,
    truncated). Each method takes a `Rational` (or an int/float coerced to one),
    calls the C ABI, and returns a new `Rational`. Domain errors (ln/pow of a
    non-positive base, sqrt of a negative, tan at a singularity) return `None` —
    the C ABI returns NULL rather than raising. The BigInt backend does not
    overflow."""

    cdef Rational _unary(self, value, unimath_rat_unary fn):
        cdef Rational x = _coerce_rational(value)
        cdef unimath_rational r = fn(x._h)
        if r == NULL:
            return None
        return Rational._wrap(r)

    def sin(self, x):
        return self._unary(x, unimath_rational_sin)

    def cos(self, x):
        return self._unary(x, unimath_rational_cos)

    def tan(self, x):
        return self._unary(x, unimath_rational_tan)

    def exp(self, x):
        return self._unary(x, unimath_rational_exp)

    def ln(self, x):
        return self._unary(x, unimath_rational_ln)

    def sqrt(self, x):
        return self._unary(x, unimath_rational_sqrt)

    def atan(self, x):
        return self._unary(x, unimath_rational_atan)

    def atan2(self, y, x):
        cdef Rational ry = _coerce_rational(y)
        cdef Rational rx = _coerce_rational(x)
        cdef unimath_rational r = unimath_rational_atan2(ry._h, rx._h)
        if r == NULL:
            return None
        return Rational._wrap(r)

    def pow(self, x, e):
        cdef Rational rx = _coerce_rational(x)
        cdef Rational re = _coerce_rational(e)
        cdef unimath_rational r = unimath_rational_pow(rx._h, re._h)
        if r == NULL:
            return None
        return Rational._wrap(r)


cdef class MathRouter:
    """Fixed[int64, 32] (Q32.32) transcendentals via the auto-dispatch cores
    (CORDIC for sin/cos/atan2, Chebyshev for tan, hyperbolic-CORDIC for
    exp/sinh/cosh/tanh, Newton for sqrt, Taylor for ln). Each method takes a
    float64, converts to Q32.32, calls the C ABI, and converts back. The C ABI
    never raises: a domain error or out-of-convergence argument (hyperbolic/
    `exp` CORDIC needs `|z| <= ~1.1182`) clamps to `0.0`."""

    cdef double _unary(self, double x, unimath_fix_unary fn):
        cdef long long q = _to_q32(x)
        cdef long long r = fn(q)
        return _from_q32(r)

    def sin(self, x):
        return self._unary(<double>x, unimath_fixed_sin)

    def cos(self, x):
        return self._unary(<double>x, unimath_fixed_cos)

    def tan(self, x):
        return self._unary(<double>x, unimath_fixed_tan)

    def exp(self, x):
        return self._unary(<double>x, unimath_fixed_exp)

    def ln(self, x):
        return self._unary(<double>x, unimath_fixed_ln)

    def sqrt(self, x):
        return self._unary(<double>x, unimath_fixed_sqrt)

    def atan(self, x):
        return self._unary(<double>x, unimath_fixed_atan)

    def sinh(self, x):
        return self._unary(<double>x, unimath_fixed_sinh)

    def cosh(self, x):
        return self._unary(<double>x, unimath_fixed_cosh)

    def tanh(self, x):
        return self._unary(<double>x, unimath_fixed_tanh)

    def atan2(self, y, x):
        cdef long long qy = _to_q32(<double>y)
        cdef long long qx = _to_q32(<double>x)
        return _from_q32(unimath_fixed_atan2(qy, qx))

    def pow(self, base, exponent):
        cdef long long qb = _to_q32(<double>base)
        cdef long long qe = _to_q32(<double>exponent)
        return _from_q32(unimath_fixed_pow(qb, qe))


cdef class Conversions:
    """Cross-type conversion matrix over the UniMath C ABI. The C ABI never
    raises: a NaN/Inf source (rational target) or a representation overflow
    (fixed target) clamps to `None` / `0.0`; nil in -> None out. Interval
    results are widened enclosures (a NaN interval on nil)."""

    def rational_from_f64(self, x):
        cdef unimath_rational r = unimath_rational_from_f64(<double>x)
        if r == NULL:
            return None
        return Rational._wrap(r)

    def rational_from_fixed(self, value, int frac_bits):
        cdef Fixed f = _coerce_fixed(value, frac_bits)
        cdef unimath_rational r = unimath_rational_from_fixed(f._raw, frac_bits)
        if r == NULL:
            return None
        return Rational._wrap(r)

    def bigfloat_from_rational(self, value):
        cdef Rational r = _coerce_rational(value)
        cdef unimath_bigfloat h = unimath_bigfloat_from_rational(r._h)
        if h == NULL:
            return None
        return BigFloat._wrap(h)

    def bigint_from_bigfloat(self, value):
        cdef BigFloat f = _coerce_bigfloat(value)
        cdef unimath_bigint h = unimath_bigint_from_bigfloat(f._h)
        if h == NULL:
            return None
        return BigInt._wrap(h)

    def bigint_from_rational(self, value):
        cdef Rational r = _coerce_rational(value)
        cdef unimath_bigint h = unimath_bigint_from_rational(r._h)
        if h == NULL:
            return None
        return BigInt._wrap(h)

    def fixed_from_rational(self, value, int frac_bits):
        cdef Rational r = _coerce_rational(value)
        cdef long long q = unimath_fixed_from_rational(r._h, frac_bits)
        return Fixed._from_raw(q, frac_bits)

    def interval_from_bigfloat(self, value):
        cdef BigFloat f = _coerce_bigfloat(value)
        return Interval._wrap(unimath_interval_from_bigfloat(f._h))

    def interval_from_rational(self, value):
        cdef Rational r = _coerce_rational(value)
        return Interval._wrap(unimath_interval_from_rational(r._h))

    def interval_from_bigint(self, value):
        cdef BigInt b = _coerce(value)
        return Interval._wrap(unimath_interval_from_bigint(b._h))
