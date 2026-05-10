const std = @import("std");

const Arg = @import("../op.zig").Arg;
const binary = @import("binary.zig");
const opcode = @import("../../encoder/lib.zig").opcode;

pub fn cmp(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    try binary.readWrite("cmp", opcode.cmp, writer, written, dst, src);
}
