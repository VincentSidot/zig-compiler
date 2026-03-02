# Zig x86-64 Instruction Encoder and Runtime Demo

Small Zig project for encoding x86-64 instructions and executing generated machine code from memory.

## What it does

- Provides an instruction encoder under `src/encoder/`
- Builds a demo in `src/main.zig` that emits machine code at runtime
- Loads and executes that generated code via `src/runner.zig`

## Requirements

- Zig (latest stable recommended)

## Quick Start

Build the project:

```bash
zig build
```

Run the demo executable:

```bash
zig build run
```

Run tests:

```bash
zig build test
```

## Project Layout

- `src/main.zig`: runtime code generation demo
- `src/runner.zig`: memory loader/executor
- `src/encoder/`: x86-64 encoding library and opcode implementations
- `src/encoder/tests/`: encoder test suite
- `build.zig`: build graph (`run`, `test` steps)
- `docs/`: notes and reference documents

## Notes

This project executes generated machine code from memory. Run only trusted code.
