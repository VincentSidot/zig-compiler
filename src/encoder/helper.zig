const std = @import("std");
const builtin = @import("builtin");
const Endian = std.builtin.Endian;
const native_endian = builtin.cpu.arch.endian();

pub inline fn extractBits(comptime T: type, value: T) [@sizeOf(T)]u8 {
    // encoder expect little endian.
    const target_endian: Endian = .little;

    return @bitCast(if (target_endian == native_endian) value else @byteSwap(value));
}

pub const RetKind = enum {
    Default,
    Far,
    Near,
};
