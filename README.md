# Zig x86-64 Encoder & JIT Compiler

A learning-focused project exploring compiler backends, JIT compilation, and low-level x86-64 machine code generation in Zig.

**Status**: ✅ Active development, all tests passing (~12,300 LOC across 126 files)

## What This Project Does

This is a from-scratch implementation of:
- **Custom x86-64 instruction encoder** - hand-coded machine code generation without LLVM
- **JIT compilation system** - compiles and executes code in memory
- **Brainfuck compiler** - full-featured compiler with interpreter, JIT, and ELF generation modes
- **ELF executable generator** - creates standalone Linux x86-64 binaries

This is **not a production tool**. It's an exploration sandbox for learning compiler construction, instruction encoding, and runtime code execution.

## Quick Start

```bash
# Build the project
zig build

# Run all tests
zig build test

# JIT compile and run Brainfuck (default mode)
zig build run -- brainfuck/hello.bf

# Interpret mode (no compilation)
zig build run -- -m interpret brainfuck/hello.bf

# Generate standalone ELF executable
zig build run -- -m elf -o hello brainfuck/hello.bf
chmod +x hello
./hello

# Save JIT-compiled machine code to file
zig build run -- -m jit -o hello.bin brainfuck/hello.bf

# Measure execution time
zig build run -- -t brainfuck/mandelbrot.bf
```

## Project Architecture

### Directory Structure

```
zig-compiler/
├── src/
│   ├── backend/          # Code generation and execution
│   │   ├── encoder/      # x86-64 instruction encoder
│   │   ├── engine/       # High-level assembly API
│   │   └── elf/          # ELF executable generation
│   ├── frontend/         # Language frontends
│   │   └── brainfuck/    # Brainfuck tokenizer, lexer, compiler
│   ├── apps/             # Application entry points
│   ├── loader.zig        # Executable memory loader
│   ├── args.zig          # CLI argument parsing
│   └── main.zig          # Main entry point
├── brainfuck/            # Sample Brainfuck programs
├── docs/                 # Documentation
└── build.zig             # Build configuration
```

### Component Overview

#### 1. Backend - Instruction Encoder (`src/backend/encoder/`)

Hand-coded x86-64 machine code generation with comprehensive instruction support:

**Supported Instructions:**
- **Data Movement**: MOV, LEA, PUSH, POP
- **Arithmetic**: ADD, SUB, INC, DEC, CMP
- **Bitwise**: AND, OR, XOR, TEST
- **Control Flow**: CALL, RET, JMP, conditional jumps (JE, JNE, JL, JG, JLE, JGE, JA, JB, etc.)
- **System**: SYSCALL

**Features:**
- All operand size variants (8-bit, 16-bit, 32-bit, 64-bit)
- Register and memory operands
- Immediate values
- Proper REX prefix handling for 64-bit operations
- ModR/M and SIB byte encoding
- **1000+ test cases** validating against real x86-64 behavior

**Key Files:**
- `opcode.zig` - Instruction encoding implementations
- `reg.zig` - Register definitions and utilities (~691 LOC)
- `factory.zig` - Byte writing utilities
- `tests/` - Comprehensive test suite per instruction

#### 2. Backend - Assembly Engine (`src/backend/engine/`)

High-level assembly API with automatic label resolution and symbol patching:

**Features:**
- Fluent API for instruction emission
- Two-pass layout: size calculation → code emission
- Label allocation and binding for branch targets
- Symbol system for relocatable addresses
- Automatic fixup resolution for forward/backward jumps
- Memory-safe with proper cleanup

**Key Files:**
- `engine.zig` - Main engine implementation (~190 LOC)
- `op.zig` - Type-safe operand definitions (~601 LOC)
- `ir.zig` - Intermediate representation
- `layout.zig` - Two-pass layout algorithm (~250 LOC)
- `lower.zig` - IR to machine code lowering

**Example Usage:**
```zig
var engine = Engine.init(allocator);
defer engine.deinit();

// Allocate a label
const loop_start = try engine.label();

// Emit instructions
engine.mov(.rax, .immediate(42));
try engine.bind(loop_start);  // Define label position
engine.add(.rax, .immediate(1));
engine.cmp(.rax, .immediate(100));
engine.jl(.{ .label = loop_start });  // Jump back
engine.ret(.default);

// Finalize and get machine code
try engine.finalize();
const code = engine.bytecode();
```

#### 3. Backend - ELF Generator (`src/backend/elf/`)

Creates valid ELF64 executables for Linux x86-64:

**Features:**
- ELF64 header generation
- Program header management
- Multiple segments (text, data, bss)
- Virtual memory address calculation
- Symbol patching for relocations
- Direct file output

**Key Files:**
- `engine.zig` - ELF construction API (~338 LOC)
- `lib.zig` - Public exports

#### 4. Frontend - Brainfuck (`src/frontend/brainfuck/`)

Complete Brainfuck language implementation with multiple execution modes:

**Components:**
- **Tokenizer** (`tokenizer.zig`) - Character stream → tokens
- **Lexer** (`lexer.zig`) - Token processing and validation
- **Interpreter** (`runner.zig`) - Direct interpretation without compilation
- **JIT Compiler** (`compiler.zig`) - Brainfuck → x86-64 machine code (~299 LOC)

**Compiler Features:**
- Optimized instruction sequences
- Run-length encoding for repeated operations
- Efficient loop handling with jumps
- System call integration for I/O
- Stack alignment for proper ABI compliance

**Key Files:**
- `compiler.zig` - JIT compilation logic
- `runner.zig` - Interpreter implementation
- `lib.zig` - Public API

#### 5. Memory Loader (`src/loader.zig`)

Safe execution of dynamically generated machine code:

**Features:**
- `mmap`-based executable memory allocation
- Type-safe function pointer wrappers
- Enforces C calling convention
- Proper memory protection (`PROT_EXEC | PROT_READ`)
- Load from memory or file
- Automatic cleanup with `deinit()`

**Key File:**
- `loader.zig` - Function loader implementation (~126 LOC)

## CLI Reference

```
Usage: rce [options] <input.bf>

Options:
  -h, --help            Show this help message
  -m, --mode <mode>     Choose execution mode:
                        - interpret: Direct interpretation (no compilation)
                        - jit: Compile to machine code and execute (default)
                        - elf: Generate standalone ELF executable
  -o, --output <path>   Write output to file:
                        - For jit mode: save machine code bytecode
                        - For elf mode: executable path (mandatory)
  -t, --time            Measure and display execution time
```

## Execution Modes

### 1. Interpret Mode
Direct interpretation without compilation. Useful for debugging and understanding program behavior.

```bash
zig build run -- -m interpret brainfuck/hello.bf
```

### 2. JIT Mode (Default)
Compiles to x86-64 machine code and executes in memory. Fast execution with ~300-400µs compilation overhead for small programs.

```bash
zig build run -- brainfuck/hello.bf
zig build run -- -m jit -t brainfuck/mandelbrot.bf  # With timing
```

### 3. ELF Mode
Generates a standalone executable. The binary can be distributed and run without Zig or this compiler.

```bash
zig build run -- -m elf -o hello brainfuck/hello.bf
chmod +x hello
./hello
```

**Generated ELF details:**
- Statically allocates 30,000-byte tape in BSS segment
- Proper segment alignment and permissions
- Entry point setup with syscall-based exit
- Typically 1-2KB for simple programs

## Sample Programs

The `brainfuck/` directory contains test programs:

| File | Description | Complexity |
|------|-------------|-----------|
| `hello.bf` | Classic "Hello World!" | Simple |
| `cell.bf` | Cell manipulation test | Simple |
| `interactive_echo.bf` | Interactive I/O | Medium |
| `mandelbrot.bf` | Mandelbrot set generator | Complex (~12KB) |

## Testing

### Running Tests

```bash
# Run all tests (encoder + engine + integration)
zig build test

# Run specific test file
zig test src/backend/encoder/tests/mov.zig
```

### Test Coverage

**Encoder Tests** (`src/backend/encoder/tests/`):
- **1000+ test cases** across all instructions
- Tests for every operand size variant (8/16/32/64-bit)
- Register-to-register, register-to-memory, immediate values
- Validates against expected machine code bytes

**Engine Tests** (`src/backend/engine/tests/`):
- Label allocation and binding
- Forward and backward jumps
- Symbol patching
- Instruction emission through high-level API

**Integration Tests** (`src/tests/`):
- Complete function compilation and execution
- Fibonacci number generation via JIT
- Loader functionality

### Validation Methodology

The project uses `objdump` for ground-truth validation:

1. Emit machine code bytes
2. Write to temporary file
3. Disassemble with `objdump -D -b binary -m i386:x86-64`
4. Verify instruction matches expected assembly

See `docs/tester.md` for the testing workflow.

## Development Workflow

### Adding New Instructions

1. **Implement encoding** in `src/backend/encoder/opcode/<instruction>.zig`
2. **Test with tester** using `tester.zig` (see `docs/tester.md`)
3. **Add test cases** in `src/backend/encoder/tests/`
4. **Update engine helpers** if needed in `src/backend/engine/helper/`
5. **Run full test suite** with `zig build test`

### Code Organization Principles

- **Explicit module boundaries**: encoder, engine, frontend are independent
- **Test-driven validation**: Every instruction has tests before integration
- **Allocator-aware**: All dynamic memory uses explicit allocators
- **Error handling**: Zig-style error unions throughout
- **Documentation**: Comments explain *why*, not *what*

## Documentation

- **`docs/engine.md`** - How the assembly engine works (two-pass assembly, labels, symbols, IR)
- **`docs/elf.md`** - How ELF generation works (segments, headers, virtual memory, patching)
- **`docs/registers.md`** - x86-64 register reference (including 8/16/32/64-bit variants)
- **`docs/tester.md`** - Instruction testing workflow with `objdump`
- **`docs/failed.md`** - Known encoding issues (currently empty ✅)

## Technical Details

### Two-Pass Assembly

The engine uses a two-pass approach for efficient code generation:

**Pass 1 - Layout:**
- Calculate size of each instruction
- Determine label offsets
- Build fixup list for unresolved references

**Pass 2 - Emission:**
- Generate final machine code bytes
- Apply fixups with known offsets
- Emit relocatable code

### Symbol System

Symbols enable relocatable code patterns:

```zig
const data_sym = try engine.symbol();

// Use symbol in code (unresolved)
engine.mov(.rdi, .{ .sym = .{ .id = data_sym, .kind = .abs64 } });

// Later: patch with actual address
const code = try engine.takeBytes();
const actual_address: u64 = 0x7fff_0000_1000;
try engine.patch(code, data_sym, actual_address);
```

Used extensively in ELF generation for data segment references.

### Memory Safety

- All allocations tracked with explicit allocators
- Proper cleanup via `defer` and `deinit()`
- No hidden allocations
- Type-safe function pointers with enforced calling conventions

## Performance

**Typical JIT compilation overhead:**
- Hello World: ~300-400µs (includes compilation + execution)
- Mandelbrot: Variable based on complexity
- Interpretation mode: 10-100x slower than JIT for compute-heavy code

**Code size:**
- Encoder generates compact machine code
- Typical Brainfuck program: 200-500 bytes of x86-64
- ELF executables: 1-2KB for simple programs

## AI Usage & Validation

This project uses AI tools primarily for:
- Test case generation and boilerplate
- Intel manual documentation review
- Learning assistance when exploring new x86-64 features

**Validation approach:**
- **Tool-driven validation** via `objdump` disassembly
- **Real execution tests** on hardware
- **Manual code review** for all core implementations
- **LLM output treated as untrusted** until validated

Core instruction encoding and engine logic are hand-written and validated, not generated.

## Risks & Limitations

⚠️ **This project executes dynamically generated machine code**

- Only run on systems you control
- Only process trusted inputs
- Experimental - may break between commits
- Not production-ready
- Linux x86-64 only
- Prioritizes learning over API stability

**Known Limitations:**
- 30,000-byte fixed tape size (standard Brainfuck)
- Linux-only (uses Linux syscalls and `mmap`)
- x86-64 only (no 32-bit or other architectures)
- Limited optimization passes
- No debugging symbols in generated code

## Future Directions

If development continues, likely next steps:

- **More instruction coverage**: floating-point (SSE/AVX), SIMD operations
- **Optimization passes**: dead code elimination, constant folding
- **Profiling/benchmarking**: systematic performance measurement
- **More language frontends**: small scripting languages, stack machines
- **Better error reporting**: source location tracking, diagnostics
- **Debugging support**: DWARF info generation
- **Cross-platform**: macOS/BSD support, ARM64 backend

The architecture is designed to support these extensions:
- Clear module boundaries
- Extensible IR system
- Pluggable frontend interface
- Symbol system supports complex relocations

## Building & Requirements

**Requirements:**
- Zig 0.14.0+ (tested with master branch)
- Linux x86-64 system
- `objdump` for validation (optional, only for development)

**Build commands:**
```bash
zig build              # Build executable
zig build test         # Run tests
zig build run -- args  # Build and run with arguments
```

## Project Philosophy

1. **Learn by building end-to-end** - Complete working system at each stage
2. **Test assumptions with real code** - Execute on hardware, not just theory
3. **Validate with tools** - Trust `objdump` and real execution, not intuition
4. **Iterate fast** - Prioritize learning velocity over perfection
5. **Document intent** - Explain why decisions were made
6. **Structured for growth** - Clean boundaries enable future expansion

## Contributing

This is a personal learning project, but feedback and suggestions are welcome:

- **Bug reports**: Open an issue with reproducible test case
- **Documentation improvements**: PRs welcome
- **Instruction encoding fixes**: Include `objdump` validation
- **Test cases**: Always appreciated

Please note: This project prioritizes learning exploration over production readiness. Feature requests should align with educational goals.

## License

[Your license here]

## References & Resources

**Intel Documentation:**
- Intel® 64 and IA-32 Architectures Software Developer's Manual
- Volume 2: Instruction Set Reference

**Zig Resources:**
- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Zig Standard Library](https://ziglang.org/documentation/master/std/)

**x86-64 Resources:**
- [OSDev Wiki - X86-64](https://wiki.osdev.org/X86-64)
- [ELF Specification](https://refspecs.linuxfoundation.org/elf/elf.pdf)

**Similar Projects:**
- [GNU Lightning](https://www.gnu.org/software/lightning/)
- [DynASM](https://luajit.org/dynasm.html)
- [AsmJit](https://asmjit.com/)

---

**Current State**: All systems operational ✅ | 126 files | ~12,300 LOC | 0 compilation errors
