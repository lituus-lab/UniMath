# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
import unimath


def test_version():
    assert unimath.version() == "0.1.0"
    assert unimath.__version__ == "0.1.0"