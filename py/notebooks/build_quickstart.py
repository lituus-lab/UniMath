# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""Author py/notebooks/quickstart.ipynb, then execute it so the committed file
carries real outputs for GitHub to render. Run from the repo root:

    python3 py/notebooks/build_quickstart.py

CI re-executes the notebook against an installed wheel; this script only
regenerates it after an API change."""
import os

import nbformat as nbf
from nbclient import NotebookClient

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "quickstart.ipynb")

CELLS = [
    ("md", """# UniMath — Python quickstart

`unimath` is a Cython extension over the UniMath C ABI, shipped as a
self-contained wheel: the native library travels inside the package, so
installing it needs neither Nim nor a compiler.

```
pip install UniMath-lituus
```

CI installs the wheel the release actually publishes and executes this
notebook against it, so a change that breaks the API breaks the build — but
only cell *execution* is checked, not that a printed value still matches
what's committed here."""),
    ("md", "## The API"),
    ("code", """import unimath

unimath.version(), unimath.__version__"""),
    ("md", """## BigInt

Arbitrary-precision integers. Constructs from a Python `int` of any size;
arithmetic and comparison operators coerce a plain `int` operand."""),
    ("code", """from unimath import BigInt

a = BigInt(-123456789)
b = BigInt(1_000_000_000_000) * BigInt(1_000_000_000_000)
print("a =", a)
print("b =", b)
print("a * b =", a * b)
print("b // 7 =", b // BigInt(7))
print("b % 7 =", b % BigInt(7))"""),
    ("md", """## Fixed

Q-format fixed-point: `Fixed(value, frac_bits=N)` stores `value` scaled by
`2^N`. `value()` converts back to a Python `float`."""),
    ("code", """from unimath import Fixed

x = Fixed(3, frac_bits=32)
y = Fixed(2, frac_bits=32)
print("x + y =", (x + y).value())
print("x * y =", (x * y).value())
print("x // y =", (x // y).value())"""),
    ("md", """## BigFloat

Arbitrary-precision binary floating point, constructed from a Python `float`.
`to_f64()` rounds back to the nearest `float`."""),
    ("code", """from unimath import BigFloat

fa = BigFloat(10.0)
fb = BigFloat(3.0)
print("fa + fb =", (fa + fb).to_f64())
print("fa * fb =", (fa * fb).to_f64())
print("fa / fb =", (fa / fb).to_f64())"""),
    ("md", """## Rational

Exact fractions. `Rational(num, den)` always reduces to lowest terms with a
positive denominator; `numerator()`/`denominator()` return the reduced
`BigInt` pair."""),
    ("code", """from unimath import Rational

ra = Rational(1, 2)
rb = Rational(1, 3)
print("1/2 + 1/3 =", (ra + rb).to_f64())
print("1/2 * 1/3 =", (ra * rb).to_f64())
red = Rational(4, 8)
print("4/8 reduces to", red.numerator(), "/", red.denominator())"""),
    ("md", """## Interval

Directed-rounding intervals: every operation widens its result so it
encloses the true value, even under float rounding."""),
    ("code", """from unimath import Interval

ia = Interval(1.0, 2.0)
ib = Interval(3.0, 4.0)
print("ia + ib =", ia + ib)
print("sqrt([4, 9]) =", Interval(4.0, 9.0).sqrt())"""),
    ("md", """## Complex

The square root of a negative number is not real, and neither is the
logarithm. `unimath.sqrt` and `unimath.log` return a complex there instead of
raising, and the argument's type decides which one: a `float` gives a `float`
or a builtin `complex`, a `BigFloat` gives a `BigFloat` or a `BigComplex`, and
so on down the backends.

The Nim core cannot do this — it resolves return types at compile time, so it
exposes a separately named `csqrt`. Python decides per value, so the choice
lives here."""),
    ("code", """from unimath import sqrt, log

print("sqrt(-1) =", sqrt(-1))
print("sqrt(4)  =", sqrt(4))
print("log(-1)  =", log(-1))"""),
    ("md", """Arithmetic over `float64` takes and returns Python's builtin `complex`, so
results feed straight into `cmath` or NumPy. Division uses Smith's algorithm:
the textbook `(ac+bd)/(c²+d²)` overflows to NaN long before the quotient
itself does."""),
    ("code", """from unimath import ComplexMath

cm = ComplexMath()
print("abs(3+4i)   =", cm.abs(3 + 4j))
print("sqrt(-3-4i) =", cm.sqrt(-3 - 4j))
print("exp(i*pi)   =", cm.exp(complex(0, 3.141592653589793)))
huge = complex(1e300, 1e300)
print("huge/huge   =", cm.div(huge, huge))"""),
    ("md", """The other backends have their own classes. `RationalComplex` keeps
`+ - * /`, `conj`, `norm2` and integer powers exact — a Gaussian rational
never leaves its field — while `BigComplex` carries the full transcendental
set at arbitrary precision."""),
    ("code", """from unimath import BigComplex, RationalComplex, Rational

z = RationalComplex(Rational(1, 2), Rational(3, 4))
print("norm2(1/2+3/4i) =", z.norm2())
print("(1/2+3/4i)^2    =", z ** 2)
print("abs(3+4i) big   =", float(BigComplex(3, 4).abs()))
print("ln(-1) big      =", complex(BigComplex(-1, 0).ln()))"""),
]


def main():
    nb = nbf.v4.new_notebook()
    nb.cells = [
        nbf.v4.new_markdown_cell(src) if kind == "md" else nbf.v4.new_code_cell(src)
        for kind, src in CELLS
    ]
    nb.metadata["kernelspec"] = {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    }
    # Execute from the repo root, never from py/: there, `import unimath`
    # would resolve to the py/unimath source tree instead of the installed
    # package, and the notebook would stop testing what it claims to test.
    NotebookClient(nb, timeout=120, kernel_name="python3",
                   resources={"metadata": {"path": ROOT}}).execute()
    with open(OUT, "w") as f:
        nbf.write(nb, f)
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
