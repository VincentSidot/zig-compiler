const std = @import("std");

const error_file = @import("error.zig");
const EncodingError = error_file.EncodingError;

const builtin = @import("builtin");
const Endian = std.builtin.Endian;
const native_endian = builtin.cpu.arch.endian();

pub inline fn extractBits(comptime T: type, value: T) [@sizeOf(T)]u8 {
    // encoder expect little endian.
    const target_endian: Endian = .little;

    return @bitCast(if (target_endian == native_endian) value else @byteSwap(value));
}

pub const OFFSETS = struct {
    pub const O1_REL8: usize = 1;
    pub const O2_REL8: usize = 2;
    pub const O1_JMP_REL32: usize = 1;
    pub const O2_JMP_REL32: usize = 5;
    pub const O1_JCC_REL32: usize = 2;
    pub const O2_JCC_REL32: usize = 6;
};

pub fn patch(comptime T: type, o1: usize, o2: usize, buffer: []u8, op_addr: usize, patch_value: usize) EncodingError!void {
    if (op_addr + o2 > buffer.len) {
        return EncodingError.InvalidPatchAddress;
    }

    const next_ip = op_addr + o2;
    const delta: i64 = @as(i64, @intCast(patch_value)) - @as(i64, @intCast(next_ip));
    const disp: T = std.math.cast(T, delta) orelse return EncodingError.InvalidDisplacement;
    const bytes = extractBits(T, disp);

    @memcpy(buffer[op_addr + o1 .. op_addr + o2], bytes[0..]);
}

pub const RetKind = enum {
    Default,
    Far,
    Near,
};
