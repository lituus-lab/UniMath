<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# ADR-0010: Statistical special-function boundary

- Status: Accepted
- Date: 2026-08-21

## Decision

UniMath exposes the beta function, its logarithm, and the regularized
incomplete beta function for finite float64 inputs. These are mathematical
primitives used by probability distributions, but distribution objects,
estimators, degrees of freedom, and confidence policies belong to
UniStatistics.

`logBeta(a, b)` combines native `lgamma`, stable gamma-ratio identities and a
Stirling expansion; `beta(a, b)` exponentiates that result.
`regularizedIncompleteBeta(x, a, b)` uses a continued fraction
and evaluates the complementary tail by symmetry to avoid subtracting a small
lower-tail value from one. Parameters require `a > 0`, `b > 0`, and a finite
representable `a + b`. The regularized function additionally requires
`0 <= x <= 1` and `a + b <= 200000`; the analytic cases `a == 1` or `b == 1`
are exempt. This explicit v1 bound excludes the large-shape regime where the
continued fraction does not guarantee convergence.
Invalid inputs trigger
`PreConditionDefect` while contracts are active and `ValueError` in
release/danger builds.

The C and Python surfaces are additive. The C ABI returns NaN on an invalid
domain because the existing native-float functions are value-only and expose
libm-style classifications rather than a status channel.

## Consequences

UniStatistics can implement Student and beta distributions without carrying a
second special-function implementation. UniMath does not acquire a dependency
on UniStatistics, preserving the family DAG.
