const std = @import("std");
const common = @import("common.zig");

const bitand = common.bitand;
const bitor = common.bitor;
const bitxor = common.bitxor;
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

test "BITWISE 8 bit register and memory forms" {
    try validate(RegisterMemory_8, RegisterIndex_8, "AND AL, CL", &.{ 0x20, 0xC8 }, bitand.rm8_r8, .{ .reg = .AL }, .CL);
    try validate(RegisterMemory_8, RegisterIndex_8, "OR AL, CL", &.{ 0x08, 0xC8 }, bitor.rm8_r8, .{ .reg = .AL }, .CL);
    try validate(RegisterMemory_8, RegisterIndex_8, "XOR AL, CL", &.{ 0x30, 0xC8 }, bitxor.rm8_r8, .{ .reg = .AL }, .CL);

    try validate(RegisterIndex_8, RegisterMemory_8, "AND AL, CL", &.{ 0x22, 0xC1 }, bitand.r8_rm8, .AL, .{ .reg = .CL });
    try validate(RegisterIndex_8, RegisterMemory_8, "OR AL, CL", &.{ 0x0A, 0xC1 }, bitor.r8_rm8, .AL, .{ .reg = .CL });
    try validate(RegisterIndex_8, RegisterMemory_8, "XOR AL, CL", &.{ 0x32, 0xC1 }, bitxor.r8_rm8, .AL, .{ .reg = .CL });
}

test "BITWISE 8 bit immediate forms" {
    try validate(RegisterMemory_8, u8, "AND AL, 0x7f", &.{ 0x80, 0xE0, 0x7F }, bitand.rm8_imm8, .{ .reg = .AL }, 0x7F);
    try validate(RegisterMemory_8, u8, "OR AL, 0x7f", &.{ 0x80, 0xC8, 0x7F }, bitor.rm8_imm8, .{ .reg = .AL }, 0x7F);
    try validate(RegisterMemory_8, u8, "XOR AL, 0x7f", &.{ 0x80, 0xF0, 0x7F }, bitxor.rm8_imm8, .{ .reg = .AL }, 0x7F);

    try validate(RegisterIndex_8, u8, "AND R9B, 0x01", &.{ 0x41, 0x80, 0xE1, 0x01 }, bitand.r8_imm8, .R9B, 0x01);
    try validate(RegisterIndex_8, u8, "OR R9B, 0x01", &.{ 0x41, 0x80, 0xC9, 0x01 }, bitor.r8_imm8, .R9B, 0x01);
    try validate(RegisterIndex_8, u8, "XOR R9B, 0x01", &.{ 0x41, 0x80, 0xF1, 0x01 }, bitxor.r8_imm8, .R9B, 0x01);
}

test "BITWISE 8 bit invalid high register and REX combinations" {
    var buffer: [8]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.InvalidOperand, bitand.rm8_r8(&writer, .{ .reg = .AH }, .R8B));
    try std.testing.expectError(EncodingError.InvalidOperand, bitor.r8_rm8(&writer, .SPL, .{ .reg = .AH }));
}

test "BITWISE 8 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, bitxor.rm8_r8(&writer, .{ .reg = .AL }, .CL));
}
