#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Local mirror of the CI dco job: a commit must carry a Signed-off-by trailer.
# pre-commit passes the commit-msg file path as $1.
set -eu
msg_file="$1"
if ! grep -qE '^Signed-off-by: .+ <.+@.+>' "$msg_file"; then
  echo "Missing Signed-off-by trailer in the commit message." >&2
  echo "Re-run with:  git commit -s   (or  git commit -s --amend)" >&2
  exit 1
fi
