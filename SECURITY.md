<!-- SPDX-License-Identifier: Apache-2.0 -->
<!-- Copyright 2026 lituus-lab -->
# Security Policy

Report vulnerabilities privately (email the maintainer — see git history),
not via a public issue. Include: description + impact, minimal reproducer,
affected version (`unimath_version()`).

Only the latest released line is supported. The `0.1.x` C ABI is not yet frozen.

## Surface

- C ABI trusts its callers (C pointers, lengths) and never raises; out-of-range
  input is clamped. Foreign callers validate untrusted input before calling.
- Python binding adds the domain check and raises `ValueError`/`TypeError`.
- Single-threaded, reentrant; no global mutable state.
