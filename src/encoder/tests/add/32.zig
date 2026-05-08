const std = @import("std");
const common = @import("common.zig");

const add = common.add;
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

test "ADD 32 bit register and memory forms" {
    try validate(RegisterMemory_32, RegisterIndex_32, "EAX, ECX", &.{ 0x01, 0xC8 }, add.rm32_r32, .{ .reg = .EAX }, .ECX);
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x03, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
}

test "ADD 32 bit immediate forms" {
    try validate(
        RegisterMemory_32,
        u32,
        "[EBP], 0x11223344",
        &.{ 0x67, 0x81, 0x45, 0x00, 0x44, 0x33, 0x22, 0x11 },
        add.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x1122_3344,
    );
    try validate(RegisterIndex_32, u32, "R11D, 0x01020304", &.{ 0x41, 0x81, 0xC3, 0x04, 0x03, 0x02, 0x01 }, add.r32_imm32, .R11D, 0x0102_0304);
}

test "ADD 32 bit RIP-relative memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[RIP + 0x1234], ECX",
        &.{ 0x01, 0x0D, 0x34, 0x12, 0x00, 0x00 },
        add.rm32_r32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .ECX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R9D, [RIP - 16]",
        &.{ 0x44, 0x03, 0x0D, 0xF0, 0xFF, 0xFF, 0xFF },
        add.r32_rm32,
        .R9D,
        .{ .mem = .{ .ripRelative = -16 } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[RIP + 0x1234], 0x89AB_CDEF",
        &.{ 0x81, 0x05, 0x34, 0x12, 0x00, 0x00, 0xEF, 0xCD, 0xAB, 0x89 },
        add.rm32_imm32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        0x89AB_CDEF,
    );
}

test "ADD 32 bit base-index64 memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[R8], EAX",
        &.{ 0x41, 0x01, 0x00 },
        add.rm32_r32,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .EAX,
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[R9 + 4], EAX",
        &.{ 0x41, 0x01, 0x41, 0x04 },
        add.rm32_r32,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .EAX,
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[RAX + R10*2 - 4], 0x11223344",
        &.{ 0x42, 0x81, 0x44, 0x50, 0xFC, 0x44, 0x33, 0x22, 0x11 },
        add.rm32_imm32,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{
                        .reg = .R10,
                        .scale = .x2,
                    },
                    .disp = -4,
                },
            },
        },
        0x1122_3344,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [R8]",
        &.{ 0x45, 0x03, 0x18 },
        add.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [R9 + 4]",
        &.{ 0x45, 0x03, 0x59, 0x04 },
        add.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[RAX + R10*8 + 0x10], R11D",
        &.{ 0x46, 0x01, 0x5C, 0xD0, 0x10 },
        add.rm32_r32,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{
                        .reg = .R10,
                        .scale = .x8,
                    },
                    .disp = 0x10,
                },
            },
        },
        .R11D,
    );
}

test "ADD 32 bit base-index32 memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[EBX + ECX*2], EAX",
        &.{ 0x67, 0x01, 0x04, 0x4B },
        add.rm32_r32,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = .EBX,
                    .index = .{
                        .reg = .ECX,
                        .scale = .x2,
                    },
                },
            },
        },
        .EAX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [EBX + ECX*2]",
        &.{ 0x67, 0x44, 0x03, 0x1C, 0x4B },
        add.r32_rm32,
        .R11D,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = .EBX,
                    .index = .{
                        .reg = .ECX,
                        .scale = .x2,
                    },
                },
            },
        },
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[R8D], EAX",
        &.{ 0x67, 0x41, 0x01, 0x00 },
        add.rm32_r32,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
        .EAX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [R8D]",
        &.{ 0x67, 0x45, 0x03, 0x18 },
        add.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[EBP], 0x11223344",
        &.{ 0x67, 0x81, 0x45, 0x00, 0x44, 0x33, 0x22, 0x11 },
        add.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x1122_3344,
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[ECX*4 + 0x1234], EAX",
        &.{ 0x67, 0x01, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        add.rm32_r32,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = null,
                    .index = .{
                        .reg = .ECX,
                        .scale = .x4,
                    },
                    .disp = 0x1234,
                },
            },
        },
        .EAX,
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[addr32:0x1234], EAX",
        &.{ 0x67, 0x01, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.rm32_r32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        .EAX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x03, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[addr32:0x1234], 0x11223344",
        &.{ 0x67, 0x81, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        add.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );
}

test "ADD 32 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, add.r32_rm32(&writer, .EAX, .{ .reg = .ECX }));
}
