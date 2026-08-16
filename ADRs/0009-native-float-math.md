# ADR-0009: Native float64 mathematics

## Status

Accepted.

## Context

UniMath owns the numeric layer used by the Uni* family, but its public
transcendental APIs currently target `BigFloat`, rational, fixed-point and
interval values. Consumers such as UniPlot still import `std/math` directly for
ordinary `float64` scales and would have to repeat that dependency for
transforms, polar coordinates and statistical kernels.

Moving those operations into each consumer would fragment domain semantics and
make performance comparisons impossible to audit. Reimplementing the platform
mathematics inside UniMath would add a slower, less accurate duplicate of the
system libm.

## Decision

UniMath explicitly re-exports Nim's complete `std/math` surface. Native
`float64` calls therefore use the same overloaded names as the other UniMath
backends: roots, logarithms, exponentials, trigonometric and hyperbolic
functions, `hypot`, error/gamma functions, rounding, decomposition, degree
conversion and the remaining helpers supplied by `std/math`. UniMath adds the
C99 operations missing from Nim 2.2's module, `log1p` and `expm1`, plus the
argument-once paired helper `sinCos`.

The facade delegates to the host C mathematics implementation. It promises the
IEEE-754 classifications and special cases exercised by the tests, not
bit-identical results across operating systems or libm implementations.
`sinCos` is a semantic paired operation; it does not claim a fused libm call.
The functions have no narrower domain than libm and therefore no artificial
precondition. Domain-specific consumers retain their own meaningful contracts.
The standard functions are their original Nim declarations, not wrappers.
Typed templates provide only the three additions, and `sinCos` binds its
argument once before the two operations.

Normal overload resolution selects the representation. The generic `gcd` and
`lcm` from `std/math` are deliberately excluded: UniMath already owns exact
implementations and re-exporting both makes exact-integer calls ambiguous. A consumer importing
`UniMath` therefore writes `sqrt(x)` for `float64`, `BigFloat`, `Rational`,
`Fixed` or `Interval` values and does not also import `std/math`. Code that
deliberately compares implementations can qualify direct calls as `math.sqrt`.

The C ABI is additive and uses the same scalar semantics. Python exposes a
stateless `NativeFloat` namespace. Benchmarks compare the facade with direct
`std/math` calls on the same process; they are overhead checks, not claims that
UniMath implements a faster libm.

## Consequences

UniPlot and later Uni* consumers can depend only on UniMath for transcendental
operations while retaining native performance. Domain validation that is
specific to a plot scale, geometry or statistical operation remains in that
higher-level library.

Native results can differ by a few ulps between supported platforms. Baselines
therefore record timings and representative outputs separately, and tests use
exact assertions only for identities guaranteed by the platform interface.
