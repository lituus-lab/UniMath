# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# POSIX-portable (`?=` only, no `ifeq`/`.if`): GNU make (Linux/macOS),
# mingw32-make (Windows), and BSD make (FreeBSD) all support `?=`, but only
# GNU make understands `ifeq`/`endif` -- BSD make's own conditional syntax
# (`.if`/`.endif`) is not shared with it either, so there is no single
# directive form portable across all three. The Windows-only overrides (CC,
# BIN, RUN, RM_F) come from `UniMath.nimble`'s `make` invocation as
# command-line variable assignments instead, which take precedence over `?=`
# on every make flavor without needing an in-Makefile OS branch.
#
# ROOT stays relative: `$(CURDIR)` is a GNU make builtin that BSD make leaves
# empty (it spells it `.CURDIR`), which made ROOT `/../..`. Both flavors chdir
# for `-C` before reading this file, so a relative path needs no builtin.
CC     ?= cc
ROOT   := ../..
CFLAGS := -I$(ROOT)/include -O2 -Wall -Wextra -std=c11
LIB    := $(ROOT)/libUniMath.a
BIN    ?= demo
RUN    ?= ./$(BIN)
RM_F   ?= rm -f
# The dot family calls libm `fma`; the static lib leaves it unresolved, so the
# final link supplies it. (macOS/MinGW pull libm implicitly; harmless there.)
LIBS   ?= -lm

.PHONY: all run clean
all: run
run: $(BIN)
	$(RUN)
$(BIN): demo.c $(ROOT)/include/UniMath.h $(LIB)
	$(CC) $(CFLAGS) -o $(BIN) demo.c $(LIB) $(LIBS)
# File target, not phony: `nimble cexample` already built the lib, don't redo it.
$(LIB):
	cd $(ROOT) && nimble clibStatic
clean:
	$(RM_F) $(BIN)
