# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
"""unimath — Python binding over the UniMath C library."""
from ._core import version as _version_c
from ._core import BigInt, Fixed, BigFloat, Rational, Interval, NativeFloat, Roots, Exponential, Trigonometry, Hyperbolic, Special, Constants, Reduction, FloatMath, RationalMath, MathRouter, Conversions
from ._core import ComplexMath, BigComplex, RationalComplex, FixedComplex
from ._core import sqrt, log

__version__ = _version_c().decode("ascii")


def version():
    """C library version string."""
    return _version_c().decode("ascii")


__all__ = ["version", "BigInt", "Fixed", "BigFloat", "Rational", "Interval", "NativeFloat",
           "Roots", "Exponential", "Trigonometry", "Hyperbolic", "Special",
           "Constants", "Reduction", "FloatMath", "RationalMath", "MathRouter",
           "Conversions", "ComplexMath", "BigComplex", "RationalComplex",
           "FixedComplex", "sqrt", "log", "__version__"]
