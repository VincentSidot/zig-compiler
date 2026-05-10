# Assembly Engine: How It Works

This document explains the conceptual design of the assembly engine - how it transforms high-level assembly instructions into executable machine code.

## The Problem: Forward References

Consider this simple assembly code:

```asm
    jmp end_label
    mov rax, 42
end_label:
    ret
```

**The Challenge:** How long is the jump instruction?
- If `end_label` is close (within 127 bytes), we can use a 2-byte short jump
- If it's farther, we need a 5-byte near jump
- But we can't know the distance until we know the size of all instructions in between!

This creates a **circular dependency**: the jump size depends on the label offset, but the label offset depends on the jump size.

## The Solution: Two-Pass Assembly

The engine solves this by making two passes through the code:

### Pass 1: Layout
**Goal:** Figure out where everything goes

In the first pass, we:
1. Estimate the size of each instruction (conservatively assuming worst-case)
2. Record where each label would be located
3. Track which instructions need "fixups" (adjustments after we know final positions)

After this pass, we know:
- How large the final code will be
- Where each label is located
- Which instructions reference which labels

### Pass 2: Emission
**Goal:** Generate the actual machine code

Now that we know all label positions:
1. Encode each instruction with correct sizes
2. Calculate actual offsets for jumps and calls
3. Write final machine code bytes

The result is executable machine code with all references correctly resolved.

## Intermediate Representation (IR)

**Why not encode directly?**

Instead of immediately converting assembly instructions to machine code, we first convert them into an Intermediate Representation (IR). Think of it as a middle ground between "what you want" and "raw bytes."

**Benefits:**
- **Decouples concerns:** Writing code vs encoding code are separate problems
- **Enables analysis:** We can examine all instructions before committing to encoding
- **Allows optimization:** Future passes could reorder, eliminate, or combine instructions
- **Simplifies layout:** We can calculate sizes without actually encoding

**Example IR flow:**
```
User writes:     engine.mov(.rax, .immediate(42))
       ↓
Becomes IR:      Op.mov { dst: .rax, src: .immediate(42) }
       ↓
Layout pass:     "This instruction is 7 bytes"
       ↓
Lowering pass:   Actual bytes: 48 c7 c0 2a 00 00 00
```

## Labels: Branch Targets

Labels are symbolic names for positions in code. They solve the forward reference problem.

**How labels work:**

1. **Allocation:** Reserve a label ID (just a number)
2. **Binding:** Mark a specific position in code with that label
3. **Reference:** Use the label as a jump/call target
4. **Resolution:** Calculate actual offset during emission pass

**Example:**
```
loop_start = allocate_label()        // ID: 0
    
    xor rax, rax
bind(loop_start)                      // "Label 0 is here"
    inc rax
    cmp rax, 100
    jl loop_start                     // "Jump to label 0"
```

During layout, we discover `loop_start` is at offset 3 (after the `xor` instruction). During emission, we calculate the jump needs to go back by a specific number of bytes.

## Symbols: Relocatable Addresses

Symbols represent addresses we don't know yet - typically data that exists outside the code.

**The problem they solve:**

Imagine you're compiling code that needs to access a memory buffer, but you won't know where that buffer is until runtime. You need placeholders.

**Symbol workflow:**

1. **Allocation:** Create a symbol ID
2. **Use in code:** Emit instructions that reference the symbol
3. **After finalization:** Patch the code with the actual address

**Example scenario:**
```
tape_symbol = allocate_symbol()

// Generate code that uses the symbol
mov rdi, [tape_symbol]    // "Load from wherever tape_symbol points"

// Later, after allocating memory:
tape_address = mmap(...)
patch(code, tape_symbol, tape_address)  // Fill in the actual address
```

This is crucial for:
- Data segment references
- External function addresses
- Global variables
- Position-independent code

## Memory Layout

The engine needs to calculate where everything fits in memory.

**Key concepts:**

### Instruction Sizes
Different instructions have different sizes:
- `ret` → 1 byte
- `push rax` → 1 byte
- `mov rax, 42` → 7 bytes (64-bit register + 32-bit immediate)
- `add [rdi + rbx*4 + 16], eax` → 7 bytes (complex addressing)

### Relative Offsets
Most jumps and calls use relative addressing - "jump forward 20 bytes" rather than "jump to address 0x1234."

**Why relative?**
- More compact encoding
- Position-independent code
- Smaller instruction sizes

**The calculation:**
```
Jump from offset 10 to offset 30:
- Current position after jump instruction: 15 (10 + 5 bytes for jmp)
- Target position: 30
- Relative offset: 30 - 15 = 15
- Encode: jmp +15
```

### Alignment
Some code benefits from alignment (placing at addresses divisible by 4, 8, 16, etc.):
- Performance: CPU cache lines
- Requirements: Some instructions require alignment
- Convenience: Round numbers for debugging

## Fixups: Deferred Resolution

A fixup is a "TODO: fill this in later" marker.

**When do we need fixups?**

1. **Forward jumps:** Target label hasn't been bound yet
2. **Backward jumps:** Need to calculate exact displacement
3. **Symbol references:** Address unknown until after code generation

**Fixup structure (conceptual):**
```
Fixup:
  - Location in code: byte offset 42
  - What needs fixing: a jump instruction
  - Target: label ID 3
  - How to fix: calculate relative offset to label 3, write as i32
```

**Resolution process:**
```
For each fixup:
  1. Look up target label's final offset
  2. Calculate relative displacement
  3. Write the displacement into the code at the fixup location
```

## Type Safety

The engine uses type-safe operands to catch errors at compile time.

**Register sizes:**
Different registers have different sizes:
- 64-bit: `rax`, `rbx`, `rdi`, etc.
- 32-bit: `eax`, `ebx`, `edi`, etc.
- 16-bit: `ax`, `bx`, `di`, etc.
- 8-bit: `al`, `bl`, `dil`, etc.

The type system ensures:
- You can't `mov` a 64-bit register to an 8-bit register
- Immediate values fit in their destination
- Memory operands specify size explicitly

**Memory operands:**
Memory accesses need explicit sizing:
```
mov [rdi], rax          // Error: ambiguous size
mov qword [rdi], rax    // OK: 64-bit store
mov byte [rdi], al      // OK: 8-bit store
```

## Putting It All Together

**Complete compilation flow:**

```
1. User writes high-level assembly:
   engine.mov(.rax, .immediate(0))
   label = engine.label()
   engine.bind(label)
   engine.inc(.rax)
   engine.cmp(.rax, .immediate(10))
   engine.jl(label)
   engine.ret()

2. Instructions recorded as IR:
   [mov, bind_label, inc, cmp, jcc, ret]

3. Pass 1 - Layout:
   - mov: 0-7 bytes
   - label: 7 (position marker)
   - inc: 7-10 bytes
   - cmp: 10-17 bytes
   - jcc: 17-22 bytes (creates fixup)
   - ret: 22-23 bytes
   Total size: 23 bytes

4. Pass 2 - Emission:
   - Encode mov → 7 bytes
   - Note label at offset 7
   - Encode inc → 3 bytes
   - Encode cmp → 7 bytes
   - Encode jcc: 
     * Target is offset 7
     * We're at offset 17
     * Next instruction at 17+6=23
     * Displacement: 7-23 = -16
     * Encode: 0f 8c f0 ff ff ff (jl -16)
   - Encode ret → 1 byte

5. Result: 23 bytes of executable machine code
```

## Design Principles

### Separation of Concerns
- **Engine:** High-level API, manages labels/symbols
- **IR:** Platform-independent instruction representation
- **Layout:** Calculates sizes and offsets
- **Lowering:** Converts IR to encoder calls
- **Encoder:** Generates actual x86-64 bytes

Each layer has a single responsibility.

### Memory Safety
- One allocator for all allocations
- Explicit cleanup via `deinit()`
- No hidden allocations
- All errors propagated properly

### Zero-Cost Abstractions
- High-level API compiles to same code as manual encoding
- No runtime overhead for type safety
- Labels resolved at compile-time (of generated code)

### Extensibility
The layered architecture allows:
- Adding new instructions (extend IR)
- New optimization passes (analyze IR)
- Multiple backends (different lowering implementations)
- Debug information (annotations on IR)

## Performance Characteristics

**Time Complexity:**
- Pass 1 (Layout): O(n) where n = instructions
- Pass 2 (Emission): O(n)
- Fixup resolution: O(f) where f = number of fixups
- Total: O(n) linear time

**Space Complexity:**
- IR storage: O(n)
- Label table: O(l) where l = number of labels
- Fixup list: O(f)
- Output buffer: O(n) (size of final code)

**Practical performance:**
- Small programs (<1000 instructions): microseconds
- Label resolution is very fast (hash table lookups)
- No expensive analysis or optimization passes

## Comparison to Traditional Assemblers

**Traditional assembler (e.g., NASM):**
- Parses text assembly language
- Symbol table for labels and constants
- Multiple passes for forward references
- Outputs object files with relocations
- Linker resolves external references

**This engine:**
- No parsing (direct API calls)
- Labels and symbols as typed handles
- Two passes for size calculation and emission
- Outputs ready-to-execute machine code
- No separate linking step (or manual patching)

**Tradeoffs:**
- ✅ Faster: no parsing, direct code generation
- ✅ Type-safe: errors caught at compile time
- ✅ Embedded: lives in your program
- ❌ No text format: can't write `.asm` files
- ❌ Single translation unit: no separate compilation
- ❌ Manual memory management: must handle lifetimes

## Common Patterns

### Function Generation
1. Emit prologue (save registers, set up stack)
2. Generate function body
3. Emit epilogue (restore registers, return)
4. Labels for early returns or error handling

### Loop Construction
1. Allocate label for loop start
2. Bind label at loop beginning
3. Generate loop body
4. Emit conditional jump back to start
5. Optional: label for loop exit

### Conditional Execution
1. Emit comparison
2. Conditional jump to else/end label
3. Generate true branch
4. Unconditional jump to end
5. Bind else label
6. Generate false branch
7. Bind end label

### Position-Independent Code
1. Allocate symbols for external data
2. Generate code using symbolic references
3. After finalization, patch with actual addresses
4. Result: code works at any load address

## Future Enhancements

**Possible improvements:**

### Short Jump Optimization
Currently, jumps always use 5-byte near form. Could detect when short form (2 bytes) suffices and save space.

### Register Allocation
Track register liveness to:
- Avoid unnecessary saves/restores
- Detect register conflicts
- Suggest optimal register usage

### Peephole Optimization
Analyze small instruction windows to:
- Eliminate redundant moves
- Combine operations
- Remove dead code

### Debug Information
Attach source locations to IR:
- Generate DWARF debugging info
- Map machine code back to source
- Enable debugger integration

### RIP-Relative Addressing
Use instruction pointer-relative addressing for:
- True position-independent code
- Smaller encodings
- More efficient data access

## References

For deeper understanding:

**x86-64 Architecture:**
- Intel® 64 and IA-32 Architectures Software Developer's Manual
- AMD64 Architecture Programmer's Manual

**Assembly Concepts:**
- Assemblers and Loaders (David Salomon)
- Linkers and Loaders (John R. Levine)

**Compiler Design:**
- Engineering a Compiler (Cooper & Torczon)
- Modern Compiler Implementation (Appel)

**Similar Systems:**
- GNU Lightning - portable JIT library
- DynASM - dynamic assembler for LuaJIT
- AsmJit - x86/x64 assembler library
