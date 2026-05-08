const std = @import("std");
const common = @import("common.zig");

const cmp = common.cmp;
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

test "CMP 16 bit forms" {
    try validate(RegisterMemory_16, RegisterIndex_16, "AX, CX", &.{ 0x66, 0x39, 0xC8 }, cmp.rm16_r16, .{ .reg = .AX }, .CX);
    try validate(RegisterIndex_16, RegisterMemory_16, "R8W, AX", &.{ 0x66, 0x44, 0x3B, 0xC0 }, cmp.r16_rm16, .R8W, .{ .reg = .AX });
    try validate(RegisterMemory_16, u16, "BX, 0x1234", &.{ 0x66, 0x81, 0xFB, 0x34, 0x12 }, cmp.rm16_imm16, .{ .reg = .BX }, 0x1234);
    try validate(RegisterIndex_16, u16, "R9W, 0x5678", &.{ 0x66, 0x41, 0x81, 0xF9, 0x78, 0x56 }, cmp.r16_imm16, .R9W, 0x5678);
}

test "CMP 16 bit RIP-relative memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[RIP + 0x1234], AX",
        &.{ 0x66, 0x39, 0x05, 0x34, 0x12, 0x00, 0x00 },
        cmp.rm16_r16,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R9W, [RIP - 8]",
        &.{ 0x66, 0x44, 0x3B, 0x0D, 0xF8, 0xFF, 0xFF, 0xFF },
        cmp.r16_rm16,
        .R9W,
        .{ .mem = .{ .ripRelative = -8 } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[RIP + 0x10], 0xBEEF",
        &.{ 0x66, 0x81, 0x3D, 0x10, 0x00, 0x00, 0x00, 0xEF, 0xBE },
        cmp.rm16_imm16,
        .{ .mem = .{ .ripRelative = 0x10 } },
        0xBEEF,
    );
}

test "CMP 16 bit base-index memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[R8], AX",
        &.{ 0x66, 0x41, 0x39, 0x00 },
        cmp.rm16_r16,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [R9 + 4]",
        &.{ 0x66, 0x45, 0x3B, 0x59, 0x04 },
        cmp.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[addr32:0x1234], 0x1234",
        &.{ 0x66, 0x67, 0x81, 0x3C, 0x25, 0x34, 0x12, 0x00, 0x00, 0x34, 0x12 },
        cmp.rm16_imm16,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1234,
    );
}

test "CMP 16 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, cmp.r16_imm16(&writer, .AX, 0x1234));
}
