const std = @import("std");

const encoder = @import("../../encoder/lib.zig");

pub fn syscall(writer: ?*std.Io.Writer, written: *usize) !void {
    written.* += try encoder.opcode.syscall(writer);
}
