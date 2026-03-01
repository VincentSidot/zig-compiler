const std = @import("std");
const common = @import("common.zig");

const bitand = common.bitand;
const bitor = common.bitor;
const bitxor = common.bitxor;
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

test "BITWISE 16 bit register and memory forms" {
    try validate(RegisterMemory_16, RegisterIndex_16, "AND AX, CX", &.{ 0x66, 0x21, 0xC8 }, bitand.rm16_r16, .{ .reg = .AX }, .CX);
    try validate(RegisterMemory_16, RegisterIndex_16, "OR AX, CX", &.{ 0x66, 0x09, 0xC8 }, bitor.rm16_r16, .{ .reg = .AX }, .CX);
    try validate(RegisterMemory_16, RegisterIndex_16, "XOR AX, CX", &.{ 0x66, 0x31, 0xC8 }, bitxor.rm16_r16, .{ .reg = .AX }, .CX);

    try validate(RegisterIndex_16, RegisterMemory_16, "AND AX, CX", &.{ 0x66, 0x23, 0xC1 }, bitand.r16_rm16, .AX, .{ .reg = .CX });
    try validate(RegisterIndex_16, RegisterMemory_16, "OR AX, CX", &.{ 0x66, 0x0B, 0xC1 }, bitor.r16_rm16, .AX, .{ .reg = .CX });
    try validate(RegisterIndex_16, RegisterMemory_16, "XOR AX, CX", &.{ 0x66, 0x33, 0xC1 }, bitxor.r16_rm16, .AX, .{ .reg = .CX });
}

test "BITWISE 16 bit immediate forms" {
    try validate(RegisterMemory_16, u16, "AND BX, 0x1234", &.{ 0x66, 0x81, 0xE3, 0x34, 0x12 }, bitand.rm16_imm16, .{ .reg = .BX }, 0x1234);
    try validate(RegisterMemory_16, u16, "OR BX, 0x1234", &.{ 0x66, 0x81, 0xCB, 0x34, 0x12 }, bitor.rm16_imm16, .{ .reg = .BX }, 0x1234);
    try validate(RegisterMemory_16, u16, "XOR BX, 0x1234", &.{ 0x66, 0x81, 0xF3, 0x34, 0x12 }, bitxor.rm16_imm16, .{ .reg = .BX }, 0x1234);

    try validate(RegisterIndex_16, u16, "AND R9W, 0x5678", &.{ 0x66, 0x41, 0x81, 0xE1, 0x78, 0x56 }, bitand.r16_imm16, .R9W, 0x5678);
    try validate(RegisterIndex_16, u16, "OR R9W, 0x5678", &.{ 0x66, 0x41, 0x81, 0xC9, 0x78, 0x56 }, bitor.r16_imm16, .R9W, 0x5678);
    try validate(RegisterIndex_16, u16, "XOR R9W, 0x5678", &.{ 0x66, 0x41, 0x81, 0xF1, 0x78, 0x56 }, bitxor.r16_imm16, .R9W, 0x5678);
}

test "BITWISE 16 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, bitand.r16_imm16(&writer, .AX, 0x1234));
}
