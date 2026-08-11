# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Linux/macOS only: the speed benchmark links libmpc + libmpfr + libgmp via
# pkg-config.
# POSIX-portable (`?=` only, no `ifeq`/`.if`): GNU make and BSD make share no
# conditional syntax, so overrides come from the command line instead, which
# takes precedence over `?=` on every make flavor.
#
# ROOT stays relative: `$(CURDIR)` is a GNU make builtin that BSD make leaves
# empty (it spells it `.CURDIR`). Both flavors chdir for `-C` before reading
# this file, so a relative path needs no builtin.
#
# pkg-config runs in the recipe, not in a variable: `$(shell ...)` is GNU-only
# (BSD make spells it `!=`), while backticks are plain shell everywhere.
CC     ?= cc
ROOT   := ..
CFLAGS := -I$(ROOT)/include -O2 -Wall -Wextra -std=c11
LIB    := $(ROOT)/libUniMath.a
BIN    ?= bench_speed
RUN    ?= ./$(BIN)
RM_F   ?= rm -f
PKG    ?= mpc mpfr gmp
LIBS   ?= -lm

.PHONY: all run clean
all: run
run: $(BIN)
	$(RUN)
$(BIN): bench_speed.c $(ROOT)/include/UniMath.h $(LIB)
	$(CC) $(CFLAGS) `pkg-config --cflags $(PKG)` -o $(BIN) bench_speed.c \
	  $(LIB) `pkg-config --libs $(PKG)` $(LIBS)
# File target, not phony: `nimble benchSpeed` already built the lib, don't redo it.
$(LIB):
	cd $(ROOT) && nimble clibStatic
clean:
	$(RM_F) $(BIN)
