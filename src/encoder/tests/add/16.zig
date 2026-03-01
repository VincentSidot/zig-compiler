const std = @import("std");
const common = @import("common.zig");

const add = common.add;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_16 = common.RegisterIndex_16;
const RegisterMemory_16 = common.RegisterMemory_16;

pub var validate_calls = std.atomic.Value(usize).init(0);

fn validate(
    comptime Dest: type,
    comptime Src: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn (writer: *std.io.Writer, dest: Dest, source: Src) EncodingError!usize,
    dest: Dest,
    source: Src,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_impl(Dest, Src, name, expected, tested, dest, source);
}

test "ADD 16 bit register and memory forms" {
    try validate(RegisterMemory_16, RegisterIndex_16, "AX, CX", &.{ 0x66, 0x01, 0xC8 }, add.rm16_r16, .{ .reg = .AX }, .CX);
    try validate(RegisterIndex_16, RegisterMemory_16, "R8W, AX", &.{ 0x66, 0x44, 0x03, 0xC0 }, add.r16_rm16, .R8W, .{ .reg = .AX });
}

test "ADD 16 bit immediate forms" {
    try validate(RegisterMemory_16, u16, "BX, 0x1234", &.{ 0x66, 0x81, 0xC3, 0x34, 0x12 }, add.rm16_imm16, .{ .reg = .BX }, 0x1234);
    try validate(RegisterIndex_16, u16, "R9W, 0x5678", &.{ 0x66, 0x41, 0x81, 0xC1, 0x78, 0x56 }, add.r16_imm16, .R9W, 0x5678);
}

test "ADD 16 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, add.r16_imm16(&writer, .AX, 0x1234));
}
