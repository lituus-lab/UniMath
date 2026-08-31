# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# nimibook compiles each chapter in its own process, so options given to the
# nbook driver do not reach them. This is where a chapter's own paths go.
#
# The theme comes from the nimble path, installed by `docsDeps`: a sibling
# checkout would work here and not in CI, where only this repo is checked out.
switch("path", "../src")
