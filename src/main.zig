const std = @import("std");
const log = std.log;

// Runner module for loading and executing code from memory.
const runner = @import("runner.zig");

// Encoder module for encoding assembly instructions.
const encoder = @import("encoder/lib.zig");

// Helper function for printing logic
const helper = @import("helper.zig");
const logFunctionMake = helper.logFunctionMake;
const printf = helper.printf;
const eprintf = helper.eprintf;

// Define standard options for logging.
const disableLog: bool = false;
pub const std_options: std.Options = .{
    .logFn = logFunctionMake(1024, disableLog),
    .log_level = .debug,
};

fn patch_rel32(buffer: []u8, disp_pos: usize, next_ip: usize, target_ip: usize) !void {
    const delta: i64 = @as(i64, @intCast(target_ip)) - @as(i64, @intCast(next_ip));
    const disp: i32 = std.math.cast(i32, delta) orelse return error.InvalidDisplacement;
    const bytes = encoder.extractBits(i32, disp);
    @memcpy(buffer[disp_pos .. disp_pos + 4], bytes[0..]);
}

fn patch_rel8(buffer: []u8, disp_pos: usize, next_ip: usize, target_ip: usize) !void {
    const delta: i64 = @as(i64, @intCast(target_ip)) - @as(i64, @intCast(next_ip));
    const disp: i8 = std.math.cast(i8, delta) orelse return error.InvalidDisplacement;
    const bytes = encoder.extractBits(i8, disp);
    @memcpy(buffer[disp_pos .. disp_pos + 1], bytes[0..]);
}

pub fn main() !void {

    // Encode asm/test.s with the encoder.
    const bufferSize = 512;
    var buffer: [bufferSize]u8 = undefined;
    var writer: std.io.Writer = std.io.Writer.fixed(&buffer);
    var written: usize = 0;

    // puts:
    //   mov r8, rdi
    //   call strlen
    //   mov rdx, rax
    //   mov rsi, r8
    //   mov rdi, 1
    //   mov rax, 1
    //   syscall
    //   ret
    written += try encoder.opcode.mov.r64_r64(&writer, .R8, .RDI);

    const call_strlen_disp_pos = written + 1;
    written += try encoder.opcode.call.rel32(&writer, 0);

    written += try encoder.opcode.mov.r64_r64(&writer, .RDX, .RAX);
    written += try encoder.opcode.mov.r64_r64(&writer, .RSI, .R8);
    written += try encoder.opcode.mov.rm64_imm32(&writer, .{ .reg = .RDI }, 1);
    written += try encoder.opcode.mov.rm64_imm32(&writer, .{ .reg = .RAX }, 1);
    written += try encoder.opcode.syscall(&writer);
    written += try encoder.opcode.ret(&writer, .Near);

    // strlen:
    const strlen_label = written;
    written += try encoder.opcode.bitxor.r64_rm64(&writer, .RAX, .{ .reg = .RAX }); // xor rax, rax

    const loop_label = written;
    written += try encoder.opcode.cmp.rm8_imm8(
        &writer,
        .{ .mem = .{ .baseIndex64 = .{ .base = .RDI } } },
        0,
    );

    const je_done_disp_pos = written + 1;
    written += try encoder.opcode.jcc.jz_rel8(&writer, 0);

    written += try encoder.opcode.add.r64_imm32(&writer, .RAX, 1); // inc rax
    written += try encoder.opcode.add.r64_imm32(&writer, .RDI, 1); // inc rdi

    const jmp_loop_disp_pos = written + 1;
    written += try encoder.opcode.jmp.rel8(&writer, 0);

    const done_label = written;
    written += try encoder.opcode.ret(&writer, .Near);

    // Patch branch/call displacements.
    try patch_rel32(buffer[0..written], call_strlen_disp_pos, call_strlen_disp_pos + 4, strlen_label);
    try patch_rel8(buffer[0..written], je_done_disp_pos, je_done_disp_pos + 1, done_label);
    try patch_rel8(buffer[0..written], jmp_loop_disp_pos, jmp_loop_disp_pos + 1, loop_label);

    // Load from memory
    const func = try runner.load_from_memory(buffer[0..written]);
    defer func.deinit();

    const message = "Hello from Zig!\n";

    func.call(message);
}
