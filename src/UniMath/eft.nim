# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## EFT — error-free transforms. A thin re-export of the UniAccurate engine: the
## EFT primitives (`twoSum`, `fastTwoSum`, `twoSumFast`, `twoDiff`, `twoProduct`,
## `twoSquare`, `split`, `ulp`) and the Shewchuk expansion arithmetic
## (`growExpansion`, `fastExpansionSumZeroElim`, `scaleExpansionZeroElim`,
## `estimate`, `zeroElim`). UniMath adds no EFT code of its own and no C ABI —
## UniAccurate owns the `ua_*` float64 EFT C ABI.
import UniAccurate
export UniAccurate
