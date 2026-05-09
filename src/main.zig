const std = @import("std");
const log = std.log;

pub fn main2(init: std.process.Init) !void {
    _ = init;

    const fib = @import("apps/fib.zig");
    try fib.run();
}

pub fn main(init: std.process.Init) !void {
    const brainfuck = @import("apps/brainfuck.zig");

    try brainfuck.start(init);
}

pub fn main1(init: std.process.Init) !void {
    const elf = @import("apps/elf.zig");

    try elf.generate(init.io);
}
