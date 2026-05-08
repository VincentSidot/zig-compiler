const std = @import("std");
const common = @import("common.zig");

const bitand = common.bitand;
const bitor = common.bitor;
const bitxor = common.bitxor;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_32 = common.RegisterIndex_32;
const RegisterMemory_32 = common.RegisterMemory_32;

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

test "BITWISE 32 bit register and immediate forms" {
    try validate(RegisterMemory_32, RegisterIndex_32, "AND EAX, ECX", &.{ 0x21, 0xC8 }, bitand.rm32_r32, .{ .reg = .EAX }, .ECX);
    try validate(RegisterMemory_32, RegisterIndex_32, "OR EAX, ECX", &.{ 0x09, 0xC8 }, bitor.rm32_r32, .{ .reg = .EAX }, .ECX);
    try validate(RegisterMemory_32, RegisterIndex_32, "XOR EAX, ECX", &.{ 0x31, 0xC8 }, bitxor.rm32_r32, .{ .reg = .EAX }, .ECX);

    try validate(RegisterMemory_32, u32, "AND EAX, 0x01020304", &.{ 0x81, 0xE0, 0x04, 0x03, 0x02, 0x01 }, bitand.rm32_imm32, .{ .reg = .EAX }, 0x0102_0304);
    try validate(RegisterMemory_32, u32, "OR EAX, 0x01020304", &.{ 0x81, 0xC8, 0x04, 0x03, 0x02, 0x01 }, bitor.rm32_imm32, .{ .reg = .EAX }, 0x0102_0304);
    try validate(RegisterMemory_32, u32, "XOR EAX, 0x01020304", &.{ 0x81, 0xF0, 0x04, 0x03, 0x02, 0x01 }, bitxor.rm32_imm32, .{ .reg = .EAX }, 0x0102_0304);
}

test "BITWISE 32 bit RIP-relative memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "AND [RIP + 0x1234], ECX",
        &.{ 0x21, 0x0D, 0x34, 0x12, 0x00, 0x00 },
        bitand.rm32_r32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .ECX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "OR R9D, [RIP - 16]",
        &.{ 0x44, 0x0B, 0x0D, 0xF0, 0xFF, 0xFF, 0xFF },
        bitor.r32_rm32,
        .R9D,
        .{ .mem = .{ .ripRelative = -16 } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "XOR [RIP + 0x1234], 0x89AB_CDEF",
        &.{ 0x81, 0x35, 0x34, 0x12, 0x00, 0x00, 0xEF, 0xCD, 0xAB, 0x89 },
        bitxor.rm32_imm32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        0x89AB_CDEF,
    );
}

test "BITWISE 32 bit base-index64 memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "AND [R8], EAX",
        &.{ 0x41, 0x21, 0x00 },
        bitand.rm32_r32,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .EAX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "OR R11D, [R9 + 4]",
        &.{ 0x45, 0x0B, 0x59, 0x04 },
        bitor.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "XOR [RAX + R10*2 - 4], 0x11223344",
        &.{ 0x42, 0x81, 0x74, 0x50, 0xFC, 0x44, 0x33, 0x22, 0x11 },
        bitxor.rm32_imm32,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{ .reg = .R10, .scale = .x2 },
                    .disp = -4,
                },
            },
        },
        0x1122_3344,
    );
}

test "BITWISE 32 bit base-index32 memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "AND [EBX + ECX*2], EAX",
        &.{ 0x67, 0x21, 0x04, 0x4B },
        bitand.rm32_r32,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = .EBX,
                    .index = .{ .reg = .ECX, .scale = .x2 },
                },
            },
        },
        .EAX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "OR R11D, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x0B, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        bitor.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "XOR [addr32:0x1234], 0x11223344",
        &.{ 0x67, 0x81, 0x34, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        bitxor.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );
}

test "BITWISE 32 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, bitxor.r32_rm32(&writer, .EAX, .{ .reg = .ECX }));
}
