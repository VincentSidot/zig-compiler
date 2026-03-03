const std = @import("std");
const common = @import("common.zig");

const test_op = common.test_op;
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

test "TEST 8 bit forms" {
    try validate(RegisterMemory_8, RegisterIndex_8, "AL, CL", &.{ 0x84, 0xC8 }, test_op.rm8_r8, .{ .reg = .AL }, .CL);
    try validate(RegisterMemory_8, u8, "AL, 0x7f", &.{ 0xF6, 0xC0, 0x7F }, test_op.rm8_imm8, .{ .reg = .AL }, 0x7F);
    try validate(RegisterIndex_8, u8, "R9B, 0x01", &.{ 0x41, 0xF6, 0xC1, 0x01 }, test_op.r8_imm8, .R9B, 0x01);
}

test "TEST 8 bit RIP-relative memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[RIP + 0x20], AL",
        &.{ 0x84, 0x05, 0x20, 0x00, 0x00, 0x00 },
        test_op.rm8_r8,
        .{ .mem = .{ .ripRelative = 0x20 } },
        .AL,
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[RIP + 0x20], 0x7F",
        &.{ 0xF6, 0x05, 0x20, 0x00, 0x00, 0x00, 0x7F },
        test_op.rm8_imm8,
        .{ .mem = .{ .ripRelative = 0x20 } },
        0x7F,
    );
}

test "TEST 8 bit invalid high register and REX combinations" {
    var buffer: [8]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.InvalidOperand, test_op.rm8_r8(&writer, .{ .reg = .AH }, .R8B));
    try std.testing.expectError(EncodingError.InvalidOperand, test_op.rm8_r8(&writer, .{ .reg = .SPL }, .AH));
}

test "TEST 8 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, test_op.rm8_r8(&writer, .{ .reg = .AL }, .CL));
}
