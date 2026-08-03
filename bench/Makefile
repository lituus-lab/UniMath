# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 lituus-lab
# Shell-free: `pwd` and `rm` are unavailable under mingw32-make on Windows.
# Linux/macOS only: the speed benchmark links libmpfr + libgmp via pkg-config.
ifeq ($(origin CC),default)
  ifeq ($(OS),Windows_NT)
    CC := gcc
  else
    CC := cc
  endif
endif

ROOT   := $(CURDIR)/..
CFLAGS := -I$(ROOT)/include -O2 -Wall -Wextra -std=c11 $(shell pkg-config --cflags mpfr gmp)
LIB    := $(ROOT)/libUniMath.a
LDLIBS := $(LIB) $(shell pkg-config --libs mpfr gmp) -lm

ifeq ($(OS),Windows_NT)
  BIN  := bench_speed.exe
  RUN  := $(BIN)
  RM_F := del /q
else
  BIN  := bench_speed
  RUN  := ./$(BIN)
  RM_F := rm -f
endif

.PHONY: all run clean
all: run
run: $(BIN)
	$(RUN)
$(BIN): bench_speed.c $(ROOT)/include/UniMath.h $(LIB)
	$(CC) $(CFLAGS) -o $(BIN) bench_speed.c $(LDLIBS)
# File target, not phony: `nimble benchSpeed` already built the lib, don't redo it.
$(LIB):
	cd $(ROOT) && nimble clibStatic
clean:
	$(RM_F) $(BIN)