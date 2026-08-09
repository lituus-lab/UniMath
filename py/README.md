<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# unimath — Python binding

```bash
nimble clib                                              # build libUniMath.so
cd py && python3 setup.py build_ext --inplace            # build extension
cd py && python3 -m pytest -q                            # test
```

```python
import unimath
unimath.version()       # "1.0.0"
```
