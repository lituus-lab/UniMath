<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# UniMath for Python

Multi-precision numeric types and mathematical functions for Python, backed
by the native [UniMath](https://github.com/lituus-lab/UniMath) library.

UniMath provides arbitrary-precision integers and binary floating-point
numbers, exact rational arithmetic, Q-format fixed-point numbers, and interval
arithmetic. It also exposes roots, transcendental functions, special functions,
constants, and conversions between numeric types.

## Install

```bash
pip install UniMath-lituus
```

Prebuilt wheels include the native UniMath library for Linux, macOS, and
Windows on CPython 3.10–3.14. Installing a wheel needs neither Nim nor a C
compiler.

The distribution is named `UniMath-lituus`; the Python package is imported as
`unimath`:

```python
import unimath

print(unimath.__version__)
```

## Quick start

```python
from unimath import BigInt, BigFloat, Rational, Fixed, Interval

# Arbitrary-precision integers
n = BigInt(10**30)
print(n * n)                       # 10**60

# Arbitrary-precision binary floating point
x = BigFloat(10)
print((x / BigFloat(3)).to_f64())  # 3.3333333333333335

# Exact rational arithmetic
q = Rational(1, 2) + Rational(1, 3)
print(q)                           # 5/6

# Q-format fixed-point arithmetic
price = Fixed(19.95, frac_bits=32)
quantity = Fixed(3, frac_bits=32)
print((price * quantity).value())  # approximately 59.85

# Directed-rounding interval arithmetic
domain = Interval(4.0, 9.0)
print(domain.sqrt())               # interval enclosing [2, 3]
```

## Numeric types

| Type | Purpose |
|---|---|
| `BigInt` | Arbitrary-precision signed integers |
| `BigFloat` | Arbitrary-precision binary floating-point numbers |
| `Rational` | Exact reduced fractions backed by `BigInt` |
| `Fixed` | Signed Q-format fixed-point numbers |
| `Interval` | Directed-rounding intervals enclosing the true result |

The core types support familiar Python operators such as `+`, `-`, `*`,
comparisons, and the division operations appropriate to each type.

## Mathematical functions

| Category | Python API |
|---|---|
| Roots | `Roots` |
| Exponential and logarithmic functions | `Exponential` |
| Trigonometry | `Trigonometry` |
| Hyperbolic functions | `Hyperbolic` |
| Special functions | `Special` |
| Big-float mathematics | `FloatMath` |
| Rational mathematics | `RationalMath` |
| Fixed-point mathematics | `MathRouter` |
| Mathematical constants | `Constants` |
| Range reduction | `Reduction` |
| Numeric conversions | `Conversions` |

The API includes `sin`, `cos`, `exp`, `ln`, `sqrt`, `atan`, hyperbolic
functions, `erf`, `gamma`, Bessel functions, orthogonal polynomials, and
conversions between UniMath numeric types.

For an executable tour of the API, see the
[Python quickstart notebook](https://github.com/lituus-lab/UniMath/blob/main/py/notebooks/quickstart.ipynb).

## Links

- Source, Nim API, C ABI, and design records: <https://github.com/lituus-lab/UniMath>
- Documentation: <https://lituus-lab.github.io/UniMath/>
- Issues: <https://github.com/lituus-lab/UniMath/issues>
- License: Apache-2.0

## Development

Building from source requires Nim, Nimble, a C compiler, and Cython.

```bash
nimble install -y
nimble pyLib
cd py
python3 setup.py build_ext --inplace
python3 -m pytest -q
```
