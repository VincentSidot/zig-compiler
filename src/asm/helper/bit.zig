const std = @import("std");

const Arg = @import("../op.zig").Arg;
const binary = @import("binary.zig");
const opcode = @import("../../encoder/lib.zig").opcode;

pub fn @"and"(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    try binary.readWrite("and", opcode.bitand, writer, written, dst, src);
}

pub fn @"or"(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    try binary.readWrite("or", opcode.bitor, writer, written, dst, src);
}

pub fn @"test"(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    try binary.testOp(writer, written, dst, src);
}
