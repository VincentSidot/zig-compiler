const std = @import("std");

const Arg = @import("../op.zig").Arg;
const binary = @import("binary.zig");
const opcode = @import("../../encoder/lib.zig").opcode;

pub fn xor(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    try binary.readWrite("xor", opcode.bitxor, writer, written, dst, src);
}
