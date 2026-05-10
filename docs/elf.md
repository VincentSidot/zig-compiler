# ELF Generation: Creating Executable Files

This document explains how we create ELF (Executable and Linkable Format) files from scratch - the process of turning machine code into a standalone executable that Linux can run.

## What is an ELF File?

An ELF file is a container format that packages machine code, data, and metadata into a single file that the operating system can load and execute.

**Think of it as:**
- A recipe book (ELF headers) that tells the OS how to prepare the meal
- The ingredients (your code and data)
- Instructions for where to place everything in memory

## The Challenge

You have machine code bytes in memory. How do you create a file that:
1. The operating system recognizes as executable
2. Gets loaded to the correct memory addresses
3. Has proper permissions (code=executable, data=writable)
4. Starts executing at the right entry point

This is what ELF generation solves.

## ELF File Structure

An ELF file consists of several key parts:

```
┌─────────────────────────┐
│   ELF Header            │  "This is a 64-bit executable for x86-64"
├─────────────────────────┤
│   Program Headers       │  "How to load this into memory"
│   (multiple entries)    │
├─────────────────────────┤
│   Segment 1: Code       │  Your actual machine code
│   (.text segment)       │
├─────────────────────────┤
│   Segment 2: Data       │  Initialized data
│   (.data segment)       │
├─────────────────────────┤
│   (other segments...)   │  Additional data/code
└─────────────────────────┘
```

**Note:** We don't include section headers (used by linkers). We're creating a minimal executable that just works.

## The ELF Header

The ELF header is like a business card - it identifies what kind of file this is.

**Key information it contains:**
- **Magic number**: `0x7F 'E' 'L' 'F'` - instantly identifies this as an ELF file
- **Class**: 64-bit (ELFCLASS64)
- **Endianness**: Little-endian (Intel x86-64 format)
- **Machine type**: x86-64 (EM_X86_64)
- **Entry point**: Virtual address where execution begins
- **Program header location**: Where to find the loading instructions

**Why this matters:**
Without the correct header, Linux won't even attempt to load your file. It's like trying to open a PDF in a music player - wrong format.

## Program Headers: Loading Instructions

Program headers tell the OS *how* to load your file into memory. Each header describes one loadable segment.

**Each program header specifies:**
- **Type**: Usually PT_LOAD (load this into memory)
- **File offset**: Where in the file does this segment start
- **Virtual address**: Where in memory should it be loaded
- **File size**: How many bytes to read from file
- **Memory size**: How much memory to allocate (can be larger!)
- **Permissions**: Read, Write, Execute
- **Alignment**: Memory alignment requirements (usually 4KB pages)

**Example:**
```
Program Header 1:
  Type: PT_LOAD (loadable segment)
  File offset: 0x1000
  Virtual address: 0x401000
  File size: 500 bytes
  Memory size: 500 bytes
  Permissions: Read + Execute
  Alignment: 4096 bytes (4KB pages)
  
→ Load 500 bytes from file offset 0x1000 to memory address 0x401000
→ Mark as readable and executable (code segment)
```

## Segments: Code and Data

Segments are the actual content - your code and data.

### Text Segment (Code)
Contains your executable machine code.

**Properties:**
- **Permissions**: Read + Execute (never writable!)
- **Content**: Compiled machine instructions
- **Alignment**: Page-aligned for efficient loading
- **Location**: Typically starts at 0x401000 on Linux

**Why not writable?**
For security. If code was writable, exploits could modify your program at runtime. Modern systems enforce "W^X" (Write XOR Execute) - memory is either writable or executable, never both.

### Data Segment
Contains initialized data your program needs.

**Properties:**
- **Permissions**: Read + Write (never executable!)
- **Content**: Global variables, constants, buffers
- **Alignment**: Page-aligned
- **Location**: Separate page from code

**Example use:** A buffer for Brainfuck's 30,000-byte tape.

### BSS Segment (Zero-Initialized Data)
Special segment for data that starts at zero.

**The clever optimization:**
Instead of storing 30,000 zero bytes in the file, we say:
- File size: 0 bytes
- Memory size: 30,000 bytes
- The OS automatically zeroes this memory

This saves disk space - no need to store thousands of zeros!

## Virtual Memory Addressing

The OS doesn't load your file to physical memory addresses directly. It uses virtual memory.

**Key concepts:**

### Image Base
The starting address for your executable in virtual memory. Typically 0x400000 on Linux x86-64.

**Why 0x400000?**
- Below 0x400000: reserved for OS/libraries
- 0x400000+: your program's address space
- Predictable addressing for simple executables

### Virtual Address Calculation
Each segment gets its own virtual address range:

```
Image base:     0x400000
ELF header:     0x400000 - 0x400040  (64 bytes)
Program headers: 0x400040 - 0x400100  (varies)
Code segment:   0x401000 - 0x402000  (4KB page)
Data segment:   0x402000 - 0x403000  (4KB page)
```

**Why gaps?**
Page alignment. The OS loads in 4KB pages, so segments must align to 4KB boundaries.

### Page Alignment

Modern CPUs organize memory in pages (typically 4KB).

**Benefits:**
- **Performance**: CPU cache works on page boundaries
- **Permissions**: OS sets permissions per-page
- **Protection**: Easier to enforce memory isolation

**How we handle it:**
```
1. Calculate segment size: 500 bytes
2. Round virtual address to next page: 0x401000
3. Place segment at page boundary
4. Next segment starts at next page: 0x402000
```

## The Assembly Process

Creating an ELF file involves several steps:

### 1. Segment Creation
Define what segments you need:
```
text_segment:
  - Contains: machine code
  - Permissions: Read + Execute
  - Alignment: 4KB
  
data_segment:
  - Contains: buffer for program data
  - Permissions: Read + Write
  - Alignment: 4KB
```

### 2. Content Addition
Append your compiled code and data:
```
text_segment.append(machine_code_bytes)
data_segment.reserve_bss(30000)  // 30KB of zeros
```

### 3. Layout Calculation
Determine where everything goes in the file and memory:

**Algorithm:**
```
1. Calculate header sizes (ELF + program headers)
2. For each segment:
   a. Determine file offset (after previous segment)
   b. Calculate virtual address (page-aligned)
   c. Apply alignment rules
   d. Record sizes (file vs memory)
```

**Result:** Complete memory map of the executable.

### 4. Address Resolution
Patch code to reference correct addresses.

**The problem:**
Your code might reference data, but you don't know the data's final address until layout is complete.

**Solution - Symbol Patching:**
```
1. During code generation:
   mov rdi, [TAPE_SYMBOL]  // Use placeholder
   
2. After layout:
   - data_segment virtual address: 0x402000
   - Patch instruction: mov rdi, [0x402000]
```

### 5. File Writing
Write everything to disk in the correct order:
```
1. Write ELF header (64 bytes)
2. Write program headers (56 bytes each)
3. Write segment contents at calculated offsets
4. Done! File is now executable
```

## Entry Point

The entry point is where execution begins - the first instruction the CPU executes.

**Setting the entry point:**
```
1. Mark a specific offset in code segment: byte 0
2. Calculate virtual address: 0x401000 + 0 = 0x401000
3. Write to ELF header: e_entry = 0x401000
```

**What happens at execution:**
```
1. User runs: ./my_program
2. OS reads ELF header
3. OS loads segments to virtual addresses
4. OS sets instruction pointer to entry point
5. CPU starts executing your code
```

## Permissions and Security

Each segment has permission flags that the OS enforces.

### Permission Flags
- **R (Read)**: Can read this memory
- **W (Write)**: Can modify this memory  
- **X (Execute)**: Can execute as code

### Common Combinations
```
Text segment:  R-X  (Read + Execute, no write)
Data segment:  RW-  (Read + Write, no execute)
RO data:       R--  (Read only)
```

### W^X Enforcement
Modern systems prevent memory from being both writable and executable:
- **Why**: Security against code injection attacks
- **How**: OS enforces at page level
- **Result**: Separate code and data segments

## Position-Independent Executables (PIE)

Traditional executables load at fixed addresses (0x400000). PIE executables can load anywhere.

**Benefits:**
- **ASLR**: Address Space Layout Randomization for security
- **Flexibility**: Multiple processes of same program
- **Modern standard**: Default on most systems

**How it works:**
```
Instead of:  mov rax, [0x402000]  (absolute address)
Use:         mov rax, [rip + offset]  (RIP-relative)
```

RIP (instruction pointer) relative addressing works regardless of load address.

**Our current approach:**
We generate fixed-address executables (simpler). PIE would require:
1. RIP-relative addressing throughout
2. Different relocation handling
3. More complex code generation

## Relocation and Patching

Relocation is fixing up addresses after final positions are known.

**Types of patches:**

### Absolute Addressing
Direct memory address in instruction:
```
mov rax, [0x402000]
```
Patch: Write final address (0x402000) into instruction bytes.

### Relative Addressing  
Offset from current position:
```
call +1234  (call function 1234 bytes ahead)
```
Patch: Calculate `target_address - current_address`.

### Symbol References
Placeholder for unknown addresses:
```
1. Code gen: mov rdi, [TAPE_SYMBOL]
2. Record patch: "offset 42 needs TAPE_SYMBOL address"
3. Layout determines: TAPE_SYMBOL is at 0x402000
4. Apply patch: Write 0x402000 at offset 42
```

## Minimal vs Full ELF

Our approach creates **minimal executables** - just enough to run.

**What we include:**
- ✅ ELF header
- ✅ Program headers
- ✅ Loadable segments (code + data)
- ✅ Entry point

**What we omit:**
- ❌ Section headers (used by linkers/debuggers)
- ❌ Symbol tables (debugging information)
- ❌ Dynamic linking (we're static)
- ❌ Debug information (DWARF)

**Result:**
- Smaller files (1-2KB for simple programs)
- Faster loading
- No debugging symbols
- No interposition

## Example: Brainfuck to ELF

Let's trace how a Brainfuck program becomes an ELF executable:

### Step 1: Compile Brainfuck to Machine Code
```
Input:  +++[>++<-]
Output: 313 bytes of x86-64 machine code
```

### Step 2: Create Segments
```
text_segment:
  - Append wrapper code (setup + syscall)
  - Append compiled Brainfuck code
  - Total: ~350 bytes
  
data_segment:
  - Reserve 30,000 bytes BSS (Brainfuck tape)
```

### Step 3: Calculate Layout
```
Headers:       0x000000 - 0x000120  (288 bytes)
Text payload:  0x000120 - 0x000280  (352 bytes)
Data payload:  (none - BSS only)

Memory layout:
Text segment:  0x400000 - 0x401000  (includes headers)
               Virtual: 0x400120 (code starts here)
Data segment:  0x401000 - 0x408E80  (30KB at 0x401000)
```

### Step 4: Set Entry Point
```
Entry offset: 0 (start of text payload)
Entry virtual address: 0x400120
```

### Step 5: Patch Symbols
```
Code references data segment for tape:
  mov rdi, [TAPE_SYMBOL]
  
Replace TAPE_SYMBOL with 0x401000 (data segment address)
```

### Step 6: Write File
```
Write:
  - ELF header (64 bytes)
  - 2 program headers (112 bytes)
  - Text segment bytes (352 bytes)
  - (No data segment bytes - BSS is zero-fill)
  
Total file size: 528 bytes
```

### Step 7: Make Executable
```
chmod +x output.elf
./output.elf
→ Prints "Hello World!"
```

## Debugging ELF Files

Tools for examining ELF files:

### `file` command
```bash
$ file output.elf
output.elf: ELF 64-bit LSB executable, x86-64, version 1 (SYSV)
```
Confirms it's a valid ELF file.

### `readelf` command
```bash
$ readelf -h output.elf  # Header info
$ readelf -l output.elf  # Program headers (segments)
```
Shows detailed ELF structure.

### `hexdump` command
```bash
$ hexdump -C output.elf | head -n 5
00000000  7f 45 4c 46 02 01 01 00  00 00 00 00 00 00 00 00  |.ELF............|
```
Shows raw bytes (notice `7f 45 4c 46` = ELF magic).

### `objdump` command
```bash
$ objdump -d output.elf  # Disassemble code
```
Shows actual machine instructions.

## Common Issues

### "Permission denied" when running
**Problem:** File not marked executable
**Solution:** `chmod +x output.elf`

### "Exec format error"
**Problem:** Invalid ELF header or wrong architecture
**Check:** 
- Magic number correct?
- Machine type matches CPU?
- 64-bit vs 32-bit mismatch?

### Segmentation fault on start
**Problem:** Entry point invalid or memory layout wrong
**Check:**
- Entry point within code segment?
- Segments properly aligned?
- Permissions correct?

### Code crashes accessing data
**Problem:** Symbol patching failed
**Check:**
- Data segment virtual address correct?
- Patches applied to right offsets?
- Address calculations correct?

## Performance Considerations

### File Size
- Minimal ELF: ~500 bytes overhead
- Code size: as needed
- BSS: doesn't increase file size!

**Optimization:** Use BSS for large zero-initialized buffers.

### Load Time
- Fewer segments = faster loading
- Page-aligned segments = efficient
- No dynamic linking = instant start

**Tradeoff:** Static linking makes larger files but faster startup.

### Memory Usage
- Each segment gets its own pages
- Page granularity = 4KB minimum per segment
- More segments = more memory overhead

**Practical:** Small programs still use 8-12KB (minimum pages).

## Comparison to Traditional Toolchains

### Traditional: GCC + ld
```
1. GCC compiles source to object file (.o)
2. Linker (ld) combines objects + libraries
3. Result: ELF executable with full metadata
```

**Features:**
- Section headers for debugging
- Symbol tables
- Dynamic linking support
- Relocation entries

### Our Approach
```
1. Generate machine code directly
2. Create minimal ELF wrapper
3. Result: Executable with just essentials
```

**Features:**
- No object files
- No linking step
- Minimal metadata
- Direct code generation

**Tradeoffs:**
- ✅ Simpler, faster generation
- ✅ Smaller executables
- ✅ No external tools needed
- ❌ No debugging symbols
- ❌ No separate compilation
- ❌ No library linking

## Future Enhancements

### Dynamic Linking
Support for shared libraries:
- Add INTERP segment (points to ld-linux.so)
- Generate PLT/GOT for function calls
- Add dynamic symbol table

### Section Headers
Add section metadata for debugging:
- .text, .data, .bss sections
- Section string table
- Enables `objdump -d` to show symbols

### DWARF Debug Info
Include source-level debugging:
- Line number tables
- Variable locations
- Type information
- Enables gdb/lldb debugging

### PIE Support
Position-independent executables:
- RIP-relative addressing throughout
- Relocatable segments
- ASLR compatibility

## References

**ELF Specification:**
- [ELF-64 Object File Format](https://refspecs.linuxfoundation.org/elf/elf.pdf)
- System V Application Binary Interface (AMD64)

**Tools Documentation:**
- `man elf` - ELF format documentation
- `man readelf` - ELF inspection tool
- `man execve` - How Linux loads executables

**Learning Resources:**
- [OSDev Wiki - ELF](https://wiki.osdev.org/ELF)
- Linkers and Loaders (John R. Levine)
- ELF: From The Programmer's Perspective (Hongjiu Lu)

**Similar Projects:**
- NASM - produces object files and simple executables
- Tiny ELF programs - minimal ELF research
- FASM - flat assembler with ELF support
