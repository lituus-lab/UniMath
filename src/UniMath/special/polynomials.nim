# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Classical orthogonal polynomials (Chebyshev first/second kind, Legendre,
## physicists' Hermite) via their three-term recurrences. The recurrences need
## only add/sub/mul and integer scaling, so they are generic over `Field` and
## work over `Fixed[T]`, `Rational[T]`, and floats. Integer coefficients use
## the uniform `fromInt(F, n)` overload.
##
## Each polynomial anchors on the degree-0 base case `P_0(x) == 1`. That anchor
## is not asserted by an inline `ensure:` (recursion doctrine: `result == one(F)`
## resolves to the contracted `cmp` for `BigFloat`/`Rational[BigInt]`/
## `Fixed[BigInt]`); it is exercised by the test suite. Each proc is
## `{.contractual.}` + `body:` only.
import contracts
import ../arithmetic

func chebyshevT*[F: Field](n: int, x: F): F {.contractual.} =
  ## Chebyshev polynomial of the first kind: `T_0 = 1`, `T_1 = x`,
  ## `T_n = 2x*T_{n-1} - T_{n-2}`.
  body:
    if n == 0: return one(F)
    if n == 1: return x

    var tPrev2 = one(F)
    var tPrev1 = x
    var tCur = x

    let twoX = fromInt(F, 2) * x

    for i in 2 .. n:
      tCur = (twoX * tPrev1) - tPrev2
      tPrev2 = tPrev1
      tPrev1 = tCur

    return tCur

func chebyshevU*[F: Field](n: int, x: F): F {.contractual.} =
  ## Chebyshev polynomial of the second kind: `U_0 = 1`, `U_1 = 2x`,
  ## `U_n = 2x*U_{n-1} - U_{n-2}`.
  body:
    if n == 0: return one(F)
    let twoX = fromInt(F, 2) * x
    if n == 1: return twoX

    var uPrev2 = one(F)
    var uPrev1 = twoX
    var uCur = twoX

    for i in 2 .. n:
      uCur = (twoX * uPrev1) - uPrev2
      uPrev2 = uPrev1
      uPrev1 = uCur

    return uCur

func legendreP*[F: Field](n: int, x: F): F {.contractual.} =
  ## Legendre polynomial: `P_0 = 1`, `P_1 = x`,
  ## `n*P_n = (2n-1)*x*P_{n-1} - (n-1)*P_{n-2}`.
  body:
    if n == 0: return one(F)
    if n == 1: return x

    var pPrev2 = one(F)
    var pPrev1 = x
    var pCur = x

    for i in 2 .. n:
      let t1 = (fromInt(F, 2 * i - 1) * x) * pPrev1
      let t2 = fromInt(F, i - 1) * pPrev2
      pCur = (t1 - t2) / fromInt(F, i)
      pPrev2 = pPrev1
      pPrev1 = pCur

    return pCur

func hermiteH*[F: Field](n: int, x: F): F {.contractual.} =
  ## Physicists' Hermite polynomial: `H_0 = 1`, `H_1 = 2x`,
  ## `H_n = 2x*H_{n-1} - 2(n-1)*H_{n-2}`.
  body:
    if n == 0: return one(F)
    let twoX = fromInt(F, 2) * x
    if n == 1: return twoX

    var hPrev2 = one(F)
    var hPrev1 = twoX
    var hCur = twoX

    for i in 2 .. n:
      let t1 = twoX * hPrev1
      let t2 = fromInt(F, 2 * (i - 1)) * hPrev2
      hCur = t1 - t2
      hPrev2 = hPrev1
      hPrev1 = hCur

    return hCur
