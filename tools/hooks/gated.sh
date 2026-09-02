#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Runs a nimble task through the failure gate, building the gate if it is not
# there yet. pre-commit calls this rather than `nimble <task>`: nimble exits 0
# on a task whose `exec` failed, so a hook calling it bare blocks nothing.
set -eu

cd "$(git rev-parse --show-toplevel)"

gate=build/unigate
[ "${OS:-}" = Windows_NT ] && gate=build/unigate.exe
[ -x "$gate" ] || nim c --hints:off -o:"$gate" tools/gate.nim >/dev/null

exec "$gate" "$@"
