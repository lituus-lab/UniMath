# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## String formatting for `Interval`. `$` is `"[lower, upper]"`, delegating to
## the bound's own `$`.
import ./interval_type

func `$`*[T](a: Interval[T]): string =
  mixin `$`
  "[" & $a.lower & ", " & $a.upper & "]"
