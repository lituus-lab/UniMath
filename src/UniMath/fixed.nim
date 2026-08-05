# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Fixed sub-umbrella: the Q-format `Fixed[T, FracBits]` type, its arithmetic,
## comparison, utilities, and formatting. Cross-package imports go through this
## single module; fixed sits above arithmetic in the internal layer DAG.
import ./fixed/fixed_point
import ./fixed/arithmetic
import ./fixed/comparison
import ./fixed/utils
import ./fixed/formatting
export fixed_point, arithmetic, comparison, utils, formatting
