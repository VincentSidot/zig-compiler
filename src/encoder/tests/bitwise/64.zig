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

test "BITWISE 64 bit register and immediate forms" {
    try validate(RegisterMemory_64, RegisterIndex_64, "AND RAX, RCX", &.{ 0x48, 0x21, 0xC8 }, bitand.rm64_r64, .{ .reg = .RAX }, .RCX);
    try validate(RegisterMemory_64, RegisterIndex_64, "OR RAX, RCX", &.{ 0x48, 0x09, 0xC8 }, bitor.rm64_r64, .{ .reg = .RAX }, .RCX);
    try validate(RegisterMemory_64, RegisterIndex_64, "XOR RAX, RCX", &.{ 0x48, 0x31, 0xC8 }, bitxor.rm64_r64, .{ .reg = .RAX }, .RCX);

    try validate(RegisterMemory_64, u32, "AND RAX, 1", &.{ 0x48, 0x81, 0xE0, 0x01, 0x00, 0x00, 0x00 }, bitand.rm64_imm32, .{ .reg = .RAX }, 1);
    try validate(RegisterMemory_64, u32, "OR RAX, 1", &.{ 0x48, 0x81, 0xC8, 0x01, 0x00, 0x00, 0x00 }, bitor.rm64_imm32, .{ .reg = .RAX }, 1);
    try validate(RegisterMemory_64, u32, "XOR RAX, 1", &.{ 0x48, 0x81, 0xF0, 0x01, 0x00, 0x00, 0x00 }, bitxor.rm64_imm32, .{ .reg = .RAX }, 1);
}

test "BITWISE 64 bit RIP-relative memory" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "AND [RIP + 0x1234], RAX",
        &.{ 0x48, 0x21, 0x05, 0x34, 0x12, 0x00, 0x00 },
        bitand.rm64_r64,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "OR R9, [RIP - 24]",
        &.{ 0x4C, 0x0B, 0x0D, 0xE8, 0xFF, 0xFF, 0xFF },
        bitor.r64_rm64,
        .R9,
        .{ .mem = .{ .ripRelative = -24 } },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "XOR [RIP + 0x1234], 0x89AB_CDEF",
        &.{ 0x48, 0x81, 0x35, 0x34, 0x12, 0x00, 0x00, 0xEF, 0xCD, 0xAB, 0x89 },
        bitxor.rm64_imm32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        0x89AB_CDEF,
    );
}

test "BITWISE 64 bit absolute disp32 memory" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "AND [0x1234], RAX",
        &.{ 0x48, 0x21, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        bitand.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "OR R11, [0x1234]",
        &.{ 0x4C, 0x0B, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        bitor.r64_rm64,
        .R11,
        .{ .mem = .{ .baseIndex64 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "XOR [0x1234], 0x11223344",
        &.{ 0x48, 0x81, 0x34, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        bitxor.rm64_imm32,
        .{ .mem = .{ .baseIndex64 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );
}

test "BITWISE 64 bit base-index64 memory" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "AND [R8], RAX",
        &.{ 0x49, 0x21, 0x00 },
        bitand.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "OR R11, [R9 + 4]",
        &.{ 0x4D, 0x0B, 0x59, 0x04 },
        bitor.r64_rm64,
        .R11,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "XOR [RAX + R10*2 - 4], 0x12345678",
        &.{ 0x4A, 0x81, 0x74, 0x50, 0xFC, 0x78, 0x56, 0x34, 0x12 },
        bitxor.rm64_imm32,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{ .reg = .R10, .scale = .x2 },
                    .disp = -4,
                },
            },
        },
        0x1234_5678,
    );
}

test "BITWISE 64 bit base-index64 edge cases" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "AND [R12], RAX",
        &.{ 0x49, 0x21, 0x04, 0x24 },
        bitand.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R12 } } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "OR RAX, [R13]",
        &.{ 0x49, 0x0B, 0x45, 0x00 },
        bitor.r64_rm64,
        .RAX,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R13 } } },
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "XOR [RAX - 128], RCX",
        &.{ 0x48, 0x31, 0x48, 0x80 },
        bitxor.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = -128 } } },
        .RCX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "XOR [RAX + 128], RCX",
        &.{ 0x48, 0x31, 0x88, 0x80, 0x00, 0x00, 0x00 },
        bitxor.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = 128 } } },
        .RCX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "AND [RCX*4 + 0x1234], RAX",
        &.{ 0x48, 0x21, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        bitand.rm64_r64,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = null,
                    .index = .{ .reg = .RCX, .scale = .x4 },
                    .disp = 0x1234,
                },
            },
        },
        .RAX,
    );
}

test "BITWISE 64 bit base-index32 memory" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "AND [EBX + ECX*2], RAX",
        &.{ 0x67, 0x48, 0x21, 0x04, 0x4B },
        bitand.rm64_r64,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = .EBX,
                    .index = .{ .reg = .ECX, .scale = .x2 },
                },
            },
        },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "OR R11, [addr32:0x1234]",
        &.{ 0x67, 0x4C, 0x0B, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        bitor.r64_rm64,
        .R11,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "XOR [addr32:0x1234], 0x11223344",
        &.{ 0x67, 0x48, 0x81, 0x34, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        bitxor.rm64_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );
}

test "BITWISE 64 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, bitor.r64_imm32(&writer, .RAX, 1));
}
