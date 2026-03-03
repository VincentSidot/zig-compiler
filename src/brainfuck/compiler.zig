const std = @import("std");
const log = std.log;

const builtin = @import("builtin");

const encoder = @import("../encoder/lib.zig");

const runner = @import("runner.zig");
const BrainfuckInterpreter = runner.BrainfuckInterpreter;

const loader = @import("../loader.zig");
const FunctionLoader = loader.FunctionLoader;

pub const BrainFuckCompiled = @This();

const FnType = fn (mem: *u8) callconv(.c) void;

const Bytecode = std.ArrayList(u8);

allocator: std.mem.Allocator,
program: FunctionLoader(FnType),
raw: []u8,

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
    const bytecode = try compile_inner(interpreted);
    errdefer allocator.free(bytecode);

    const program = try loader.load_from_memory(FnType, bytecode);

    return BrainFuckCompiled{
        .allocator = allocator,
        .program = program,
        .raw = bytecode,
    };
}

pub fn execute(compiled: *const BrainFuckCompiled, memory: []u8) void {
    const func = compiled.program.f();
    const ptr: *u8 = &memory[0];

    func(ptr);
}

pub fn deinit(compiled: BrainFuckCompiled) void {
    // Free the executable mapping and compiled bytecode copy.
    compiled.program.deinit();
    compiled.allocator.free(compiled.raw);
}

const op = encoder.opcode;
const reg = encoder.register;
const extractBits = encoder.extractBits;

fn compile_inner(interpreted: *BrainfuckInterpreter) ![]u8 {
    const allocator = interpreted.allocator;
    var writer_alloc = std.io.Writer.Allocating.init(allocator);
    errdefer writer_alloc.deinit();

    const writer = &writer_alloc.writer;
    var written: usize = 0;

    // We will need to keep track of the loop stack for handling '[' and ']'
    var loop_stack = std.ArrayList(usize).empty;
    defer loop_stack.deinit(allocator);

    var putc_stack = std.ArrayList(usize).empty;
    defer putc_stack.deinit(allocator);

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
                @panic("Not yet implemented");
            },
            .output => {
                // Push the position of the call instruction to the stack for
                // backpatching later.
                try putc_stack.append(allocator, written);
                // Placeholder will be backpatched later.
                written += try op.call.rel32(writer, 0);
            },
            .loop_start => {
                const loop_start_addr = written;
                // Placeholder will be backpatched later.
                written += try op.jcc.jz_rel32(writer, 0);
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
                const loop_end_jnz_addr = written;

                // Emit placeholder backward branch at ']': jnz back to loop body.
                written += try op.jcc.jnz_rel32(writer, 0);

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

    const putc_offset = written;

    // Then setup the putc function.
    // Backup the tape register on the stack
    written += try op.push.r64(writer, TAPE_REGISTER);

    // write, 1, buf, size
    // rax, rdi, rsi, rdx

    // Set the buff to the tape register
    written += try op.mov.r64_r64(writer, .RSI, TAPE_REGISTER);
    // Set the size to 1
    written += try op.mov.r64_imm64_auto(writer, .RDX, 1);
    // Set the file descriptor for stdout (1)
    written += try op.mov.r64_imm64_auto(writer, .RDI, 1);
    // Set the syscall number for write (1)
    written += try op.mov.r64_imm64_auto(writer, .RAX, 1);
    // Make the syscall
    written += try op.syscall(writer);
    // Restore the tape register from the stack
    written += try op.pop.r64(writer, TAPE_REGISTER);
    // Return from the putc function
    written += try op.ret(writer, .Default);

    // Backpatch the putc calls with the correct offset to the putc function.
    while (putc_stack.pop()) |call_addr| {
        const buffer = writer.buffer;
        try op.call.patch_rel32(buffer, call_addr, putc_offset);
    }

    return try writer_alloc.toOwnedSlice();
}

fn diff(a: usize, b: usize) i32 {
    return @as(i32, @intCast(a)) - @as(i32, @intCast(b));
}
