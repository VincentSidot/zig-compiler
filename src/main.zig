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
    const T = void;

    const toto: T = undefined;

    printf("Test: {any}", .{toto});
}

pub fn main2() !void {
    printf("Hello, World!\n", .{});

    // Prints to stderr, ignoring potential errors.
    const path = "./compiled/out.bin";
    const func = try runner.load(path);
    defer func.deinit();

    log.info("Executing loaded function from {s}", .{path});
    func.call("Hello from Zig!\n");
}
