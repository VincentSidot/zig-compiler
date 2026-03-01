const std = @import("std");
const common = @import("common.zig");

const bitand = common.bitand;
const bitor = common.bitor;
const bitxor = common.bitxor;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_64 = common.RegisterIndex_64;
const RegisterMemory_64 = common.RegisterMemory_64;

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

test "BITWISE 64 bit register and memory forms" {
    try validate(RegisterMemory_64, RegisterIndex_64, "AND RAX, RCX", &.{ 0x48, 0x21, 0xC8 }, bitand.rm64_r64, .{ .reg = .RAX }, .RCX);
    try validate(RegisterMemory_64, RegisterIndex_64, "OR RAX, RCX", &.{ 0x48, 0x09, 0xC8 }, bitor.rm64_r64, .{ .reg = .RAX }, .RCX);
    try validate(RegisterMemory_64, RegisterIndex_64, "XOR RAX, RCX", &.{ 0x48, 0x31, 0xC8 }, bitxor.rm64_r64, .{ .reg = .RAX }, .RCX);

    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "AND R11, [RIP+0x1234]",
        &.{ 0x4C, 0x23, 0x1D, 0x34, 0x12, 0x00, 0x00 },
        bitand.r64_rm64,
        .R11,
        .{ .mem = .{ .ripRelative = 0x1234 } },
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "OR R11, [RIP+0x1234]",
        &.{ 0x4C, 0x0B, 0x1D, 0x34, 0x12, 0x00, 0x00 },
        bitor.r64_rm64,
        .R11,
        .{ .mem = .{ .ripRelative = 0x1234 } },
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "XOR R11, [RIP+0x1234]",
        &.{ 0x4C, 0x33, 0x1D, 0x34, 0x12, 0x00, 0x00 },
        bitxor.r64_rm64,
        .R11,
        .{ .mem = .{ .ripRelative = 0x1234 } },
    );
}

test "BITWISE 64 bit immediate forms" {
    try validate(RegisterMemory_64, u32, "AND RAX, 1", &.{ 0x48, 0x81, 0xE0, 0x01, 0x00, 0x00, 0x00 }, bitand.rm64_imm32, .{ .reg = .RAX }, 1);
    try validate(RegisterMemory_64, u32, "OR RAX, 1", &.{ 0x48, 0x81, 0xC8, 0x01, 0x00, 0x00, 0x00 }, bitor.rm64_imm32, .{ .reg = .RAX }, 1);
    try validate(RegisterMemory_64, u32, "XOR RAX, 1", &.{ 0x48, 0x81, 0xF0, 0x01, 0x00, 0x00, 0x00 }, bitxor.rm64_imm32, .{ .reg = .RAX }, 1);

    try validate(RegisterIndex_64, u32, "AND R9, 0x11223344", &.{ 0x49, 0x81, 0xE1, 0x44, 0x33, 0x22, 0x11 }, bitand.r64_imm32, .R9, 0x1122_3344);
    try validate(RegisterIndex_64, u32, "OR R9, 0x11223344", &.{ 0x49, 0x81, 0xC9, 0x44, 0x33, 0x22, 0x11 }, bitor.r64_imm32, .R9, 0x1122_3344);
    try validate(RegisterIndex_64, u32, "XOR R9, 0x11223344", &.{ 0x49, 0x81, 0xF1, 0x44, 0x33, 0x22, 0x11 }, bitxor.r64_imm32, .R9, 0x1122_3344);
}

test "BITWISE 64 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, bitor.r64_imm32(&writer, .RAX, 1));
}
