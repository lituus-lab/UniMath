# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Hyperbolic sub-umbrella: fixed-point CORDIC `sinh`/`cosh`/`tanh`/`exp`.
## Cross-package imports go through this single module; hyperbolic sits above
## trigonometry in the internal layer DAG.
import ./hyperbolic/cordic
export cordic
