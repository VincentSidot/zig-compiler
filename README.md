# ig x86-64 Encoder - Playground

Learning-first project focused on:
- Zig practice (now more deliberate practice than initial learning),
- compiler/backend experimentation,
- JIT compilation mechanics,
- language implementation ideas.

This is not a production tool. It is an exploration sandbox that may evolve into something larger if the direction proves worthwhile.

## Project Intent

This repository is intentionally iterative:
- build pieces end-to-end,
- test assumptions with real executable code,
- learn by implementing and measuring.

Current experiments include:
- x86-64 instruction encoding,
- executable memory loading,
- Brainfuck interpreter,
- Brainfuck-to-native JIT compilation.

## Risk and Stability

Use at your own risk.

This project:
- executes dynamically generated machine code,
- is experimental and may break between commits,
- prioritizes learning velocity over API stability.

Only run trusted inputs and trusted bytecode on systems you control.

## AI Usage

AI/LLM tools are used mainly for:
- test-writing assistance,
- learning/review support when reading Intel documentation.

For low-level correctness, trust comes from tool-driven validation (for example `objdump` output), not from LLM claims.

Direct AI code generation for core implementation is intentionally limited to avoid losing project-specific code knowledge and ownership.

All AI-generated output is treated as untrusted until reviewed and validated with local builds/tests/benchmark runs.
Final design and merge decisions stay manual.

## What Exists Today

- `src/encoder/`: custom x86-64 encoder
- `src/loader.zig`: maps and executes code from memory
- `src/brainfuck/`: tokenizer, lexer, interpreter, JIT compiler
- `src/main.zig`: CLI runner
- `src/tests/loader.zig`: loader + encoded-function integration tests (including encoded Fibonacci)
- `brainfuck/`: sample BF programs (`hello`, `cell`, `interactive_echo`, `mandelbrot`)
- `test-policy.md`: complex test strategy

## CLI

```text
Usage: rce [options] <input.bf>

Options:
  -h, --help            Show help
  -m, --mode <mode>     interpret | jit (default: jit)
  -o, --output <path>   Write compiled JIT machine code to a file
```

## Quick Start

```bash
zig build
zig build test
zig build run -- brainfuck/hello.bf
zig build run -- -m interpret brainfuck/hello.bf
```

## Growth Direction

The codebase is kept structured so it can scale if continued:
- explicit module boundaries (`encoder`, `loader`, `brainfuck`, `tests`),
- increasing integration coverage,
- policy-driven complex testing (`test-policy.md`).

If the project continues, likely next steps are deeper backend correctness tests, better profiling/benchmark harnesses, and language/runtime expansion beyond Brainfuck.
