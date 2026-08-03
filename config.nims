# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## UniMath build config. amd64 float paths need -ffp-contract=off (keeps EFT
## identities valid) and -mfma (lets math.fma lower natively).
when defined(amd64):
  switch("passC", "-mfma")
  switch("passC", "-ffp-contract=off")