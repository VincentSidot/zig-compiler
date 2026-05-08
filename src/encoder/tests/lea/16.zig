const std = @import("std");
const common = @import("common.zig");

const lea = common.lea;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_16 = common.RegisterIndex_16;
const RegisterMemory_16 = common.RegisterMemory_16;

fn validate(
    comptime Dest: type,
    comptime Src: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn (writer: *std.Io.Writer, dest: Dest, source: Src) EncodingError!usize,
    dest: Dest,
    source: Src,
) !void {
    try validate_impl(Dest, Src, name, expected, tested, dest, source);
}

test "LEA 16 bit memory forms" {
    try validate(RegisterIndex_16, RegisterMemory_16, "AX, [RIP+0x1234]", &.{ 0x66, 0x8D, 0x05, 0x34, 0x12, 0x00, 0x00 }, lea.r16_m, .AX, .{ .mem = .{ .ripRelative = 0x1234 } });
    try validate(RegisterIndex_16, RegisterMemory_16, "R11W, [R9+4]", &.{ 0x66, 0x45, 0x8D, 0x59, 0x04 }, lea.r16_m, .R11W, .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } });
    try validate(RegisterIndex_16, RegisterMemory_16, "R11W, [addr32:0x1234]", &.{ 0x66, 0x67, 0x44, 0x8D, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 }, lea.r16_m, .R11W, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });
}

test "LEA 16 bit invalid reg source" {
    var buffer: [8]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.InvalidOperand, lea.r16_m(&writer, .AX, .{ .reg = .CX }));
}

test "LEA 16 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.WriterError, lea.r16_m(&writer, .AX, .{ .mem = .{ .ripRelative = 0x10 } }));
}
