# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Rational sub-umbrella: the generic exact `Rational[T]` type, `gcd`/`lcm`,
## arithmetic, and comparison. Cross-package imports go through this single
## module; rational sits above arithmetic in the internal layer DAG.
import ./rational/gcd
import ./rational/rational_type
import ./rational/arithmetic
import ./rational/comparison
export gcd, rational_type, arithmetic, comparison
