const std = @import("std");
const log = std.log;

const Writer = std.Io.Writer;

const builtin = @import("builtin");

const encoder = @import("../encoder/lib.zig");

const runner = @import("runner.zig");
const BrainfuckInterpreter = runner.BrainfuckInterpreter;

const loader = @import("../loader.zig");
const FunctionLoader = loader.FunctionLoader;

const helper = @import("../helper.zig");
const setRawMode = helper.setRawMode;
const restoreTerminal = helper.restoreTerminal;

const Engine = @import("../asm/engine.zig").Engine;

/// Native-code version of a Brainfuck program plus its executable mapping.
pub const BrainFuckCompiled = @This();

const FnType = fn (mem: *u8) callconv(.c) void;

const Bytecode = std.ArrayList(u8);

allocator: std.mem.Allocator,
program: FunctionLoader(FnType),
raw: []u8,

/// Compiles a lowered Brainfuck program to native x86-64 code and loads it into executable memory.
pub fn compile(interpreted: *BrainfuckInterpreter) !BrainFuckCompiled {
    // Use the same allocator as the interpreter
    const allocator = interpreted.allocator;

    // Compile the Brainfuck code into bytecode
    //
    // In this implementation, we will expect following:
    //
    // - The memory address is passed via the first argument (rdi register)
    // - All the logic will be implemented arround rax register
    // - The bytecode will be a sequence of x86-64 machine code instructions
    // - The bytecode will be executed as a function with the signature:
    // `fn (mem: []u8) callconv(.c) void`
    // const bytecode = try compile_inner(interpreted);
    const bytecode = try compile_inner_engine(interpreted);
    errdefer allocator.free(bytecode);

    const program = try loader.load_from_memory(FnType, bytecode);

    return BrainFuckCompiled{
        .allocator = allocator,
        .program = program,
        .raw = bytecode,
    };
}

/// Executes a compiled Brainfuck program against `memory`.
pub fn execute(compiled: *const BrainFuckCompiled, memory: []u8) !void {
    const func = compiled.program.f();
    const ptr: *u8 = &memory[0];

    try setRawMode();
    defer restoreTerminal() catch {};

    func(ptr);
}

/// Releases the executable mapping and owned machine-code bytes.
pub fn deinit(compiled: BrainFuckCompiled) void {
    // Free the executable mapping and compiled bytecode copy.
    compiled.program.deinit();
    compiled.allocator.free(compiled.raw);
}

const op = encoder.opcode;
const reg = encoder.register;
const extractBits = encoder.extractBits;

fn compile_inner_engine(interpreted: *BrainfuckInterpreter) ![]u8 {
    const allocator = interpreted.allocator;

    var engine = Engine.init(allocator);
    errdefer engine.deinit();

    const _putc = try engine.label();
    const PUTC: Engine.CallTarget = .{ .label = _putc };

    const _getc = try engine.label();
    const GETC: Engine.CallTarget = .{ .label = _getc };

    const LoopStack = struct {
        start: Engine.Label,
        end: Engine.Label,
    };

    var loop_stack = std.ArrayList(LoopStack).empty;
    defer loop_stack.deinit(allocator);

    // R12
    const TAPE_REGISTER: Engine.Arg = .r12;
    // [R12]
    const TAPE_REGISTIER_MEM: Engine.Arg = .{ .mem = .{ .reg = .r12, .size = .byte } };
    const Arg = Engine.Arg;

    // Generate the code.

    engine.push(TAPE_REGISTER);
    engine.mov(TAPE_REGISTER, .rdi);

    for (interpreted.program) |code| {
        switch (code.kind) {
            .add => |disp| {
                if (builtin.mode == .Debug) {
                    if (disp < -128 or disp > 127) {
                        log.warn(
                            "Disp value {d} is out of range for 8-bit immediate. It will be truncated to fit.",
                            .{disp},
                        );
                    }
                }

                const trunc: i8 = @truncate(disp);
                const raw: u8 = @bitCast(trunc);

                engine.add(
                    TAPE_REGISTIER_MEM,
                    Arg.raw8(raw),
                );
            },
            .move => |disp| {
                engine.add(TAPE_REGISTER, Arg.immediate(disp));
            },
            .input => {
                engine.call(GETC);
            },
            .output => {
                engine.call(PUTC);
            },
            .loop_start => {
                const loop_start = try engine.label();
                const loop_end = try engine.label();

                try engine.bind(loop_start);
                engine.@"test"(TAPE_REGISTIER_MEM, Arg.raw8(0xFF));
                engine.jcc(.e, .{ .label = loop_end });

                try loop_stack.append(allocator, .{
                    .start = loop_start,
                    .end = loop_end,
                });
            },
            .loop_end => {
                const loop = loop_stack.pop() orelse {
                    return error.UnmatchedLoopEnd;
                };

                engine.@"test"(TAPE_REGISTIER_MEM, Arg.raw8(0xFF));
                engine.jcc(.ne, .{ .label = loop.start });
                try engine.bind(loop.end);
            },
        }
    }

    engine.pop(TAPE_REGISTER);
    engine.ret();

    // Define PUTC & GETC functions

    const SYS_read = 0;
    const SYS_write = 1;

    const STDIN_FD: usize = 0;
    const STDOUT_FD: usize = 1;

    try sys_tape_arg3_engine(
        TAPE_REGISTER,
        &engine,
        _putc,
        SYS_write,
        STDOUT_FD,
        1,
    );
    try sys_tape_arg3_engine(
        TAPE_REGISTER,
        &engine,
        _getc,
        SYS_read,
        STDIN_FD,
        1,
    );

    const bytecode = try engine.finalize();

    return bytecode;
}

fn sys_tape_arg3_engine(
    comptime TAPE_REG: Engine.Arg,
    engine: *Engine,
    label: Engine.Label,
    sys: usize,
    arg1: usize,
    arg2: usize,
) !void {

    // Define label
    try engine.bind(label);

    engine.push(TAPE_REG);

    if (TAPE_REG != .rsi) {
        engine.mov(.rsi, TAPE_REG);
    }

    engine.mov(.rdx, Engine.Arg.unsigned(arg2));
    engine.mov(.rdi, Engine.Arg.unsigned(arg1));
    engine.mov(.rax, Engine.Arg.unsigned(sys));
    engine.syscall();
    engine.pop(TAPE_REG);
    engine.ret();

    return;
}

fn compile_inner_legacy(interpreted: *BrainfuckInterpreter) ![]u8 {
    const allocator = interpreted.allocator;

    var writer_alloc = std.Io.Writer.Allocating.init(allocator);
    errdefer writer_alloc.deinit();

    const writer = &writer_alloc.writer;
    var written: usize = 0;

    // We will need to keep track of the loop stack for handling '[' and ']'
    var loop_stack = std.ArrayList(usize).empty;
    defer loop_stack.deinit(allocator);

    const CallStackOp = packed struct {
        const ValueType = @Int(std.builtin.Signedness.unsigned, @bitSizeOf(usize) - 1);

        kind: enum(u1) {
            PUTC,
            GETC,
        },
        value: ValueType,
    };

    var call_stack = std.ArrayList(CallStackOp).empty;
    defer call_stack.deinit(allocator);

    // The tape register will hold the current memory cell address.
    // We will use R12 for this purpose.
    const TAPE_REGISTER = reg.r64.R12;

    // Save the tape register on the stack to restore before returning to
    // zig code.
    written += try op.push.r64(writer, TAPE_REGISTER);

    // Mov rdi to rax
    written += try op.mov.r64_r64(writer, TAPE_REGISTER, .RDI);

    // Iterate over the Brainfuck code and generate bytecode
    for (interpreted.program) |code| {
        switch (code.kind) {
            .add => |disp| {
                // Disp is i32 which can be negative.
                // Add disp to [TAPE_REGISTER]

                if (builtin.mode == .Debug) {
                    // Check if disp is within the range of -128 to 127 else
                    // log a warning that the value will be truncated to fit
                    // into 8 bits.

                    if (disp < -128 or disp > 127) {
                        log.warn(
                            "Disp value {d} is out of range for 8-bit immediate. It will be truncated to fit.",
                            .{disp},
                        );
                    }
                }

                // Truncate disp to 8 bits (modulo 256)
                const trunc: i8 = @truncate(disp);
                const raw: u8 = @bitCast(trunc);

                written += try op.add.rm8_imm8(
                    writer,
                    .{ .mem = .{ .baseIndex64 = .{ .base = TAPE_REGISTER } } },
                    raw,
                );
            },
            .move => |disp| {
                // Disp is i32 which can be negative.
                // Add disp to TAPE_REGISTER

                const raw: u32 = @bitCast(disp);
                written += try op.add.r64_imm32(
                    writer,
                    TAPE_REGISTER,
                    raw,
                );
            },
            .input => {
                try call_stack.append(allocator, .{
                    .kind = .GETC,
                    .value = @intCast(written),
                });
                // Placeholder will be backpatched later.
                written += try op.call.rel32(writer, 0);
            },
            .output => {
                // Push the position of the call instruction to the stack for
                // backpatching later.
                try call_stack.append(allocator, .{
                    .kind = .PUTC,
                    .value = @intCast(written),
                });
                // Placeholder will be backpatched later.
                written += try op.call.rel32(writer, 0);
            },
            .loop_start => {

                // Emit cmp byte and 0, to check if the current cell is zero.
                written += try op.@"test".rm8_imm8(
                    writer,
                    .{ .mem = .{ .baseIndex64 = .{ .base = TAPE_REGISTER } } },
                    0xFF,
                );

                const loop_start_addr = written;
                // Placeholder will be backpatched later.
                written += try op.jcc.rel32(writer, .e, 0);
                // Push the position of the jump instruction to the stack for
                // backpatching later.
                try loop_stack.append(allocator, loop_start_addr);
            },
            .loop_end => {
                // Fetch the position of the matching loop start instruction
                // from the stack
                const loop_start_addr = loop_stack.pop() orelse {
                    return error.UnmatchedLoopEnd;
                };
                const loop_body_addr = loop_start_addr + 6; // jcc rel32 size

                // Emit the test instruction to check if the current cell is zero.
                written += try op.@"test".rm8_imm8(
                    writer,
                    .{ .mem = .{ .baseIndex64 = .{ .base = TAPE_REGISTER } } },
                    0xFF,
                );

                const loop_end_jnz_addr = written;

                // Emit placeholder backward branch at ']': jnz back to loop body.
                written += try op.jcc.rel32(writer, .ne, 0);

                const buffer = writer.buffer;
                // Patch the ']' jnz to jump back to the loop body.
                try op.jcc.patch_rel32(buffer, loop_end_jnz_addr, loop_body_addr);

                // Patch '[' branch to skip loop and land right after the closing jnz.
                try op.jcc.patch_rel32(buffer, loop_start_addr, written);
            },
        }
    }

    // Pop back the original tape register value from the stack before returning
    // to zig code.
    written += try op.pop.r64(writer, TAPE_REGISTER);

    // After the code, setup the exit sequence for the function.
    // This will be a simple `ret` instruction.
    written += try op.ret(writer, .Default);

    const SYS_read = 0;
    const SYS_write = 1;

    const STDIN_FD: usize = 0;
    const STDOUT_FD: usize = 1;

    const putc_offset = written;
    written += try sys_tape_arg3_legacy(TAPE_REGISTER, writer, SYS_write, STDOUT_FD, 1);

    const getc_offset = written;
    written += try sys_tape_arg3_legacy(TAPE_REGISTER, writer, SYS_read, STDIN_FD, 1);

    // Backpatch the putc calls with the correct offset to the putc function.
    while (call_stack.pop()) |call_addr| {
        var patch_value: usize = undefined;
        switch (call_addr.kind) {
            .GETC => {
                patch_value = getc_offset;
            },
            .PUTC => {
                patch_value = putc_offset;
            },
        }

        const buffer = writer.buffer;
        try op.call.patch_rel32(buffer, call_addr.value, patch_value);
    }

    return try writer_alloc.toOwnedSlice();
}

fn sys_tape_arg3_legacy(
    comptime TAPE_REG: reg.r64,
    writer: *Writer,
    sys: usize,
    arg1: usize,
    arg2: usize,
) !usize {
    var written: usize = 0;

    // Backup the tape register on the stack
    written += try op.push.r64(writer, TAPE_REG);

    if (TAPE_REG != reg.r64.RSI) {
        // Move the tape register to rsi
        written += try op.mov.r64_r64(writer, .RSI, TAPE_REG);
    }

    // Move the syscall arguments to the correct registers
    written += try op.mov.r64_imm64_auto(writer, .RDX, arg2);
    written += try op.mov.r64_imm64_auto(writer, .RDI, arg1);
    // Move the syscall number to rax
    written += try op.mov.r64_imm64_auto(writer, .RAX, sys);

    // Make the syscall
    written += try op.syscall(writer);

    // Restore the tape register from the stack
    written += try op.pop.r64(writer, TAPE_REG);

    // Return from the function
    written += try op.ret(writer, .Default);

    return written;
}
