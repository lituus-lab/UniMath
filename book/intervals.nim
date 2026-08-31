# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, strformat]
import lituus_theme
import UniMath

nbInit(theme = useNimibook)
useLituus()
nb.title = "Intervals"

nbText: """
## Interval

Directed-rounding intervals `Interval[T] = object` (lower, upper). Each binary
op widens with `nextDown`/`nextUp` so the result encloses the exact value; `/`
raises `DivByZeroDefect` when the divisor straddles zero. Trigonometric ranges
scan maxima and minima independently. Transcendentals widen by two ulps for the
host libm, or one ulp under `-d:correctlyRoundedLibm` when linked to a correctly
rounded backend.
"""

nbCode:
  import UniMath
  import std/math
  let ia = initInterval(1.0, 2.0)
  let ib = initInterval(3.0, 4.0)
  let isum = ia + ib
  let iprod = ia * ib
  echo "ia + ib = [", isum.lower, ", ", isum.upper, "]"
  echo "ia * ib = [", iprod.lower, ", ", iprod.upper, "]"
  let isq = sqrt(initInterval(4.0, 9.0))
  echo "sqrt([4, 9]) = [", isq.lower, ", ", isq.upper, "]"
  let isin = sin(initInterval(0.0, PI))
  echo "sin([0, pi]) = [", isin.lower, ", ", isin.upper, "]"

nbText: """
### References

- Wikipedia: [Interval arithmetic](https://en.wikipedia.org/wiki/Interval_arithmetic)
"""

nbText: """
"""

nbSave
