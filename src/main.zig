const std = @import("std");
const log = std.log;

pub fn main2(init: std.process.Init) !void {
    _ = init;

    const draft = @import("draft.zig");
    try draft.run_draft();
}

pub fn main(init: std.process.Init) !void {
    const brainfuck = @import("brainfuck.zig");

    try brainfuck.start(init);
}
