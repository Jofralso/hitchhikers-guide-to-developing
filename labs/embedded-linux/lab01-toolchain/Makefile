# Minimal Makefile for Lab 1

CC ?= gcc
CFLAGS ?= -O2 -Wall -Wextra -std=c11
LDFLAGS ?=
BUILD_DIR := bin
SRC := src/hello.c
OBJ := $(BUILD_DIR)/hello.o
BIN := $(BUILD_DIR)/hello

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(OBJ): $(SRC) | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BIN): $(OBJ)
	$(CC) $(LDFLAGS) $^ -o $@

.PHONY: all clean run
all: $(BIN)

run: $(BIN)
	$(BIN)

clean:
	rm -rf $(BUILD_DIR)
