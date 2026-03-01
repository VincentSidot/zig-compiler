const std = @import("std");
const common = @import("common.zig");

const sub = common.sub;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_8 = common.RegisterIndex_8;
const RegisterMemory_8 = common.RegisterMemory_8;

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

test "SUB 8 bit forms" {
    try validate(RegisterMemory_8, RegisterIndex_8, "AL, CL", &.{ 0x28, 0xC8 }, sub.rm8_r8, .{ .reg = .AL }, .CL);
    try validate(RegisterIndex_8, RegisterMemory_8, "AL, CL", &.{ 0x2A, 0xC1 }, sub.r8_rm8, .AL, .{ .reg = .CL });
    try validate(RegisterMemory_8, u8, "AL, 0x7f", &.{ 0x80, 0xE8, 0x7F }, sub.rm8_imm8, .{ .reg = .AL }, 0x7F);
    try validate(RegisterIndex_8, u8, "R9B, 0x01", &.{ 0x41, 0x80, 0xE9, 0x01 }, sub.r8_imm8, .R9B, 0x01);
}

test "SUB 8 bit invalid high register and REX combinations" {
    var buffer: [8]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.InvalidOperand, sub.rm8_r8(&writer, .{ .reg = .AH }, .R8B));
    try std.testing.expectError(EncodingError.InvalidOperand, sub.r8_rm8(&writer, .SPL, .{ .reg = .AH }));
}

test "SUB 8 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, sub.rm8_r8(&writer, .{ .reg = .AL }, .CL));
}
