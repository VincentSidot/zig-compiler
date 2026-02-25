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

fn Maker(comptime T: type) type {
    return union(enum) {
        const Self = @This();

        a: T,
        b: usize,

        inline fn makeA(value: T) Self {
            return Self{ .a = value };
        }

        inline fn makeB(value: usize) Self {
            return Self{ .b = value };
        }
    };
}

pub fn main() !void {
    printf("Hello, World!\n", .{});
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
