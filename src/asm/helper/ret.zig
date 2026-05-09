const std = @import("std");

const encoder = @import("../../encoder/lib.zig");
const encoder_helper = @import("../../encoder/helper.zig");

pub const RetKind = encoder_helper.RetKind;

pub fn ret(writer: ?*std.Io.Writer, written: *usize, kind: RetKind) !void {
    written.* += try encoder.opcode.ret(writer, kind);
}
