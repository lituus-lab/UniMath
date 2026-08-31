# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
## Put the lituus theme on the reference `nim doc` generates.
##
## `nimble docs` publishes two surfaces. The book carries the theme itself,
## chapter by chapter; the reference is written by the compiler and arrives
## wearing Nim's own palette, in which six tokens sit below their contrast bar.
## `nim doc` has no stylesheet option, so the theme is appended to the
## `nimdoc.out.css` it emitted: same properties, same specificity, later in the
## file, and nothing else the compiler wrote is touched.
##
## Unlike `tools/gate.nim`, this one has a dependency: it is only ever run by
## the `docs` task, which builds the book first and so cannot reach here
## without the theme installed.
##
##     nim c -r tools/theme_api.nim pages/api/nimdoc.out.css
import std/[os, strutils]
import lituus_theme

proc main(): int =
  if paramCount() != 1:
    stderr.writeLine "usage: theme_api <path to nimdoc.out.css>"
    return 2
  let stylesheet = paramStr(1)
  if not fileExists(stylesheet):
    stderr.writeLine "theme_api: no such file: " & stylesheet
    return 1
  themeNimdoc(stylesheet)
  # The check is the point of the exercise: a silent append that landed in the
  # wrong file would leave the reference unthemed and the build still green.
  let written = readFile(stylesheet)
  if "--primary-background: " & "#0c0d10" notin written and
     "--primary-background: " & "#f6f9fd" notin written:
    stderr.writeLine "theme_api: the theme did not reach " & stylesheet
    return 1
  echo "themed ", stylesheet
  0

quit(main())
