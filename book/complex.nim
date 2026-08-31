# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import std/[math, strformat]
import lituus_theme
import UniMath

nbInit(theme = useNimibook)
useLituus()
nb.title = "Complex"

nbText: """
## complex

`Complex[T]` is generic over any `Field` component, so the same type carries
`float64`, `BigFloat`, `Rational[T]` and `Fixed[T, FracBits]`. The type and its
arithmetic need nothing beyond `+ - * /`; the transcendentals in `complex_math`
need an ordered component with `sqrt`/`abs`/`arctan2` on top, which is why they
live in a layer of their own.

There is deliberately **no order** on `Complex` — no `<`, no `cmp` — and
`abs(z)` returns the component type rather than a `Complex`. That is what keeps
`Complex` a `Field` and never a `RealField`, so generic Euclidean-norm code
rejects it at compile time instead of computing `sqrt(x*x + y*y)` on a complex
pair. Rank by `norm2`, which is exact on the exact backends.

The square root of a negative number is not real, but Nim fixes return types
at compile time, so `sqrt` cannot choose between a real and a complex result
per argument. `csqrt` is the entry point that always returns a `Complex`, and
gives `0+1i` for `-1`; the real `sqrt` keeps its domain guard. Python resolves
types per value, so the binding needs no second name — `unimath.sqrt(-1)` is
`1j`, `unimath.sqrt(4)` is `2.0`.

`sqrt` and `ln` take principal values, `arg(z)` in `(-pi, pi]`, the cut along
the negative real axis. Signed zero is not honoured: the exact backends have
none, so a negative real always yields the `+i` root.
"""

nbCode:
  import UniMath
  # The promotion: a negative real, as a complex.
  echo "csqrt(-1.0) = ", csqrt(-1.0)
  echo "cln(-1.0) = ", cln(-1.0)
  # Arithmetic and the modulus.
  let cxA = complex(1.0, 2.0)
  let cxB = complex(3.0, -1.0)
  echo "(1+2i)*(3-1i) = ", cxA * cxB
  echo "(1+2i)/(3-1i) = ", cxA / cxB
  echo "abs(3+4i) = ", abs(complex(3.0, 4.0))
  echo "arg(-1+0i) = ", arg(complex(-1.0, 0.0))
  # Euler, and the principal branch on the far side of the cut.
  echo "exp(i*pi) = ", exp(complex(0.0, arg(complex(-1.0, 0.0))))
  echo "sqrt(-3-4i) = ", sqrt(complex(-3.0, -4.0))
  # Exact on the exact backend: Gaussian rationals never leave the field.
  let cxR = complex(initRational(1, 2), initRational(3, 4))
  echo "(1/2+3/4i)^2 = ", pow(cxR, 2)
  echo "norm2(1/2+3/4i) = ", cxR.norm2
  # And on the multi-precision one.
  let cxF = complex(initBigFloat(3.0, 128), initBigFloat(4.0, 128))
  echo "abs(3+4i) over BigFloat = ", toFloat64(abs(cxF))

nbSave

nbSave
