# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[base64, math, strformat]
import lituus_theme
import UniMath

nbInit(theme = useNimibook)
useLituus()
nb.title = "Floating point"

nbText: """
## Native float64 mathematics

UniMath is the single mathematics dependency for Uni* consumers. It re-exports
the useful `float64` surface from `std/math`, so ordinary overloaded names such
as `sqrt`, `sin`, `cos`, `sinh`, `erf`, `gamma`, `floor` and `frexp` coexist
with UniMath's arbitrary-precision, rational, fixed-point and interval
algorithms. `log1p`, `expm1` and the argument-once `sinCos` helper complete the
surface without forcing consumers to import `std/math` themselves.
The same umbrella import exposes `logBeta`, `beta`, and
`regularizedIncompleteBeta` for statistical algorithms.
"""

nbCode:
  let angle = PI / 4.0
  let nativePair = sinCos(angle)
  echo "sqrt(2) = ", sqrt(2.0)
  echo "log1p(1e-16) = ", log1p(1e-16)
  echo "sin/cos(pi/4) = ", nativePair
  echo "hypot(3, 4) = ", hypot(3.0, 4.0)
  echo "I_0.2(2, 5) = ", regularizedIncompleteBeta(0.2, 2.0, 5.0)

var nativePath = ""
for index in 0 .. 160:
  let
    x = -PI + 2.0 * PI * float64(index) / 160.0
    px = 40.0 + 520.0 * float64(index) / 160.0
    py = 130.0 - 90.0 * sin(x)
  nativePath.add(if index == 0: "M" else: " L")
  nativePath.add(&"{px:.2f},{py:.2f}")
# The palette is the theme's own light one, written out rather than read: an
# SVG inside a data URI is its own document and cannot see the page's CSS, so
# this card stays light on either theme. Using the theme's values makes it
# read as part of the design instead of as a stray white box.
let nativeSvg = """
<svg xmlns="http://www.w3.org/2000/svg" width="600" height="260"
     viewBox="0 0 600 260" role="img" aria-label="sin from minus pi to pi">
  <rect width="600" height="260" fill="#f6f9fd"/>
  <path d="M40 130 H560 M300 30 V230" stroke="#bec5cd" stroke-width="1"/>
  <path d=""" & nativePath & """" fill="none" stroke="#0080ff"
        stroke-width="3"/>
  <text x="40" y="250" font-family="sans-serif" font-size="13" fill="#090e13">−π</text>
  <text x="548" y="250" font-family="sans-serif" font-size="13" fill="#090e13">π</text>
  <text x="44" y="24" font-family="sans-serif" font-size="15" fill="#090e13">sin(x)</text>
</svg>"""
nbImage("data:image/svg+xml;base64," & encode(nativeSvg),
  "The embedded SVG is generated from 161 real sin evaluations during the nimib build.",
  "A sine curve generated through UniMath native float64 mathematics")

nbText: """
The C ABI exposes the same value-only operations as `unimath_f64_*` symbols;
`unimath_f64_sin_cos` returns a two-double value whose first member is sine and
second member is cosine. Python provides the stateless `NativeFloat` namespace:

```python
from unimath import NativeFloat
sine, cosine = NativeFloat.sin_cos(0.5)
radius = NativeFloat.hypot(3.0, 4.0)
probability = NativeFloat.regularized_incomplete_beta(0.2, 2.0, 5.0)
```

The C suffix remains useful because C has no overloads; statistical callers use
`unimath_f64_log_beta`, `unimath_f64_beta`, and
`unimath_f64_regularized_incomplete_beta`. The Python namespace
also exposes trigonometric, hyperbolic, special, rounding, decomposition and
classification helpers. The reproducible overhead benchmark is documented in
`benchmarks/README.md`.
"""

nbText: """
"""

nbText: """
## EFT

Error-free transforms, re-exported from the `UniAccurate` engine: `twoSum` and
`twoProduct` split a float op into its rounded result and the exact residual,
and the Shewchuk expansion arithmetic accumulates those residuals into a
non-overlapping sequence that represents the real value exactly. UniMath adds no
EFT code of its own — the engine owns it, including its `ua_*` C ABI.
"""

nbCode:
  let (s, e) = twoSum(1.0, 2.0)
  echo "twoSum(1, 2) = (", s, ", ", e, ")"
  let ex = growExpansion([1.0, 2.0], 3.0)
  echo "estimate([1,2] grown by 3) = ", estimate(ex)

nbText: """
### References

- Wikipedia: [2Sum](https://en.wikipedia.org/wiki/2Sum) — the `twoSum`
  error-free transform (Møller–Knuth).
- Wikipedia: [Kahan summation algorithm](https://en.wikipedia.org/wiki/Kahan_summation_algorithm) —
  the same compensated-summation family.
- Shewchuk, J.R. "Adaptive Precision Floating-Point Arithmetic and Fast Robust
  Geometric Predicates," *Discrete & Computational Geometry* 18, 305–363
  (1997) — the expansion arithmetic (`growExpansion`,
  `fastExpansionSumZeroElim`, `scaleExpansionZeroElim`).
"""

nbText: """
"""

nbSave
