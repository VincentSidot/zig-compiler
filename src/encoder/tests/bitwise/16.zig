const std = @import("std");
const common = @import("common.zig");

const bitand = common.bitand;
const bitor = common.bitor;
const bitxor = common.bitxor;
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

test "BITWISE 16 bit register and immediate forms" {
    try validate(RegisterMemory_16, RegisterIndex_16, "AND AX, CX", &.{ 0x66, 0x21, 0xC8 }, bitand.rm16_r16, .{ .reg = .AX }, .CX);
    try validate(RegisterMemory_16, RegisterIndex_16, "OR AX, CX", &.{ 0x66, 0x09, 0xC8 }, bitor.rm16_r16, .{ .reg = .AX }, .CX);
    try validate(RegisterMemory_16, RegisterIndex_16, "XOR AX, CX", &.{ 0x66, 0x31, 0xC8 }, bitxor.rm16_r16, .{ .reg = .AX }, .CX);

    try validate(RegisterIndex_16, RegisterMemory_16, "AND AX, CX", &.{ 0x66, 0x23, 0xC1 }, bitand.r16_rm16, .AX, .{ .reg = .CX });
    try validate(RegisterIndex_16, RegisterMemory_16, "OR AX, CX", &.{ 0x66, 0x0B, 0xC1 }, bitor.r16_rm16, .AX, .{ .reg = .CX });
    try validate(RegisterIndex_16, RegisterMemory_16, "XOR AX, CX", &.{ 0x66, 0x33, 0xC1 }, bitxor.r16_rm16, .AX, .{ .reg = .CX });

    try validate(RegisterMemory_16, u16, "AND BX, 0x1234", &.{ 0x66, 0x81, 0xE3, 0x34, 0x12 }, bitand.rm16_imm16, .{ .reg = .BX }, 0x1234);
    try validate(RegisterMemory_16, u16, "OR BX, 0x1234", &.{ 0x66, 0x81, 0xCB, 0x34, 0x12 }, bitor.rm16_imm16, .{ .reg = .BX }, 0x1234);
    try validate(RegisterMemory_16, u16, "XOR BX, 0x1234", &.{ 0x66, 0x81, 0xF3, 0x34, 0x12 }, bitxor.rm16_imm16, .{ .reg = .BX }, 0x1234);
}

test "BITWISE 16 bit RIP-relative memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "AND [RIP + 0x1234], AX",
        &.{ 0x66, 0x21, 0x05, 0x34, 0x12, 0x00, 0x00 },
        bitand.rm16_r16,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "OR R9W, [RIP - 8]",
        &.{ 0x66, 0x44, 0x0B, 0x0D, 0xF8, 0xFF, 0xFF, 0xFF },
        bitor.r16_rm16,
        .R9W,
        .{ .mem = .{ .ripRelative = -8 } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "XOR [RIP + 0x10], 0x1234",
        &.{ 0x66, 0x81, 0x35, 0x10, 0x00, 0x00, 0x00, 0x34, 0x12 },
        bitxor.rm16_imm16,
        .{ .mem = .{ .ripRelative = 0x10 } },
        0x1234,
    );
}

test "BITWISE 16 bit base-index64 memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "AND [R8], AX",
        &.{ 0x66, 0x41, 0x21, 0x00 },
        bitand.rm16_r16,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "OR R11W, [R9 + 4]",
        &.{ 0x66, 0x45, 0x0B, 0x59, 0x04 },
        bitor.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "XOR [RAX + R10*2 - 4], 0x1234",
        &.{ 0x66, 0x42, 0x81, 0x74, 0x50, 0xFC, 0x34, 0x12 },
        bitxor.rm16_imm16,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{ .reg = .R10, .scale = .x2 },
                    .disp = -4,
                },
            },
        },
        0x1234,
    );
}

test "BITWISE 16 bit base-index32 memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "AND [EBX + ECX*2], AX",
        &.{ 0x66, 0x67, 0x21, 0x04, 0x4B },
        bitand.rm16_r16,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = .EBX,
                    .index = .{ .reg = .ECX, .scale = .x2 },
                },
            },
        },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "OR R11W, [addr32:0x1234]",
        &.{ 0x66, 0x67, 0x44, 0x0B, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        bitor.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "XOR [addr32:0x1234], 0x1234",
        &.{ 0x66, 0x67, 0x81, 0x34, 0x25, 0x34, 0x12, 0x00, 0x00, 0x34, 0x12 },
        bitxor.rm16_imm16,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1234,
    );
}

test "BITWISE 16 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, bitand.r16_imm16(&writer, .AX, 0x1234));
}
