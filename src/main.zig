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

pub fn main() !void {

    // Encode a simple function that print string
    const bufferSize = 512;
    var buffer: [bufferSize]u8 = undefined;
    var writer: std.io.Writer = std.io.Writer.fixed(&buffer);
    var written: usize = 0;

    written += try encoder.opcode.mov.r64_r64(&writer, .RDX, .RSI);
    written += try encoder.opcode.mov.r64_r64(&writer, .RSI, .RDI);
    written += try encoder.opcode.mov.rm64_imm32(
        &writer,
        .{ .reg = .RDI },
        0x1, // STDOUT file descriptor
    );
    written += try encoder.opcode.mov.rm64_imm32(
        &writer,
        .{ .reg = .RAX },
        0x1, // SYS_write syscall number
    );
    written += try encoder.opcode.syscall(&writer);
    written += try encoder.opcode.ret(&writer, .Near);

    // Prints to stderr, ignoring potential errors.
    const func = try runner.load_from_memory(buffer[0..written]);
    defer func.deinit();

    // // Load from file
    // const path = "./compiled/out2.bin";
    // const func = try runner.load_from_file(path);
    // defer func.deinit();

    const message = "Hello from Zig!\n";

    func.call(message);
}
