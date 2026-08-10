<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0009: Complex layer, branch cuts, and promoting negative reals

- Status: Accepted
- Date: 2026-08-10
- Scope: UniMath

## Context

UniMath covers the reals — integers, fixed point, big floats, rationals,
intervals — and nothing above them, so `sqrt` of a negative argument can only
raise.

The behaviour to reach for is Scheme's: `(sqrt -1)` is `+i`, a single `sqrt`
whose return type depends on the *value* of its argument. Nim resolves return
types statically, so that is not reproducible in the core, and the real `sqrt`
is load bearing: `RealField` requires `sqrt(x) is typeof(x)`, which is what
lets UniLinalg write a generic Euclidean `length`.

## Decision

### Two layers, not one

`Complex[T]` is generic over any `Field` component. Splitting it the way
`float`/`float_math` and `rational`/`rational_math` are already split follows
from what each half needs:

- `complex` (type layer, after `interval`) — the type, `+ - * /`, unary `-`,
  equality, `$`, `conj`, `norm2`, integer `pow`. Needs only `Field`, so it
  holds for `float32`/`float64`, `BigFloat`, `Rational[T]` and
  `Fixed[T, FracBits]`, and imports nothing but `arithmetic` and `contracts`.
- `complex_math` (after `math_router`) — `abs`, `arg`, `polar`/`rect`, `sqrt`,
  `exp`, `ln`, `sin`, `cos`, `tan`, `sinh`, `cosh`, `tanh`, complex `pow`.
  These need `sqrt`/`abs`/`arctan2`/`ln`/`exp`/`sin`/`cos` **on the
  component**, which live in layers above every type layer — hence the
  placement above `math_router`, which is where the `Fixed` transcendentals
  are.

`vgraph.cfg` gains both names in those positions.

### No order on Complex

No `<`, `<=`, `cmp` or `sign`, and `abs(z)` returns the component `T` rather
than a `Complex[T]`. Together these keep `Complex` a `Field` and never an
`OrderedField`/`RealField`, so ordered-field generics (`sqrtNewtonGeneric`,
`lnGeneric`, a `Vector[D, T].length`) reject it at compile time instead of
computing a wrong answer from `x*x + y*y`. Callers ranking by magnitude use
`norm2`, which is exact on the exact backends; `abs` takes a root and is not.

### Branch cuts

`sqrt` and `ln` return the principal value, `arg(z)` in `(-pi, pi]`, cut along
the negative real axis. **Signed zero is not honoured**: the `+i` root is
returned for a negative real, so `csqrt(-1.0)` is `0+1i`. IEEE-754 would
distinguish `-1-0i` from `-1+0i`, but `Rational`, `BigInt` and `Fixed` have no
signed zero — a rule only half the components can follow is worse than a
uniform one.

`pi` for the cut is derived as `arctan2(0, -1)` on the component rather than
read from `constants`, so `ln` of a negative real lands exactly on the value
`arg` reports, whatever the backend's own constant rounds to.

### The promotion is a separate name, and Python gets the real thing

`csqrt(x: T): Complex[T]` and `cln(x: T): Complex[T]` promote where the real
functions raise. That is what a statically typed language can offer for
a value-dependent return type; changing `sqrt`'s return type under a
compile flag was rejected — it would break `RealField`, the C ABI and every
caller according to how the library was built.

The Python binding resolves types per value and so needs no second name: `unimath.sqrt(-1)` returns a complex, `unimath.sqrt(4)` a
float. `Complex[float64]` maps to Python's builtin `complex` so the result
interoperates with `cmath` and NumPy.

### Verification

MPC (`libmpc`, the complex counterpart of MPFR, same authors and build
system) is the oracle, wired into `oracles/` under the existing strategy: out
of the default gate, built by `nimble buildOracles`, run by
`nimble testOracle`. Being LGPL it is linked only by the oracle binaries,
which are gitignored and never shipped — the same arrangement MPFR and GMP
already have, and UniMath stays Apache-2.0.

## Consequences

`exp`, `sin`, `cos` and `atan` over `Complex` also fall out of the existing
generic series for free: `expTaylor`, `sinTaylor`, `cosTaylor`, `atanTaylor`,
`factorial` and `binomial` are bounded on `Field`, which `Complex` satisfies.
The `complex_math` entry points use closed forms instead, which need one real
transcendental per component and stay accurate far from the origin, but the
series remain available.

`Complex` shadows `std/complex`'s type of the same name; that one is
restricted to `SomeFloat` and cannot carry `BigFloat` or `Rational`, so it is
not reusable here. Importing both modules in one file is ambiguous and needs a
qualifier.

An exact Scheme-style numeric tower — `(sqrt 4)` returning the exact integer
`2` via the existing `isqrt` — is explicitly **not** part of this decision. It
changes the real `sqrt`, not just adds to it, and is deferred.
