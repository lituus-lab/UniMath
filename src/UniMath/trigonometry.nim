# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Trigonometry sub-umbrella: generic Taylor `sin`/`cos`/`atan`, fixed-point
## CORDIC (`sin`/`cos`/`atan2`), compile-time LUT `sin`/`cos`, and the
## Chebyshev/minimax `tan`. Cross-package imports go through this single
## module; trigonometry sits above exponential in the internal layer DAG.
import ./trigonometry/taylor
import ./trigonometry/cordic
import ./trigonometry/lut
import ./trigonometry/chebyshev
export taylor, cordic, lut, chebyshev
