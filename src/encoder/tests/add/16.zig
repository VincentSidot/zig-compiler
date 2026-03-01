const std = @import("std");
const common = @import("common.zig");

const add = common.add;
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

test "ADD 16 bit register and memory forms" {
    try validate(RegisterMemory_16, RegisterIndex_16, "AX, CX", &.{ 0x66, 0x01, 0xC8 }, add.rm16_r16, .{ .reg = .AX }, .CX);
    try validate(RegisterIndex_16, RegisterMemory_16, "R8W, AX", &.{ 0x66, 0x44, 0x03, 0xC0 }, add.r16_rm16, .R8W, .{ .reg = .AX });
}

test "ADD 16 bit immediate forms" {
    try validate(RegisterMemory_16, u16, "BX, 0x1234", &.{ 0x66, 0x81, 0xC3, 0x34, 0x12 }, add.rm16_imm16, .{ .reg = .BX }, 0x1234);
    try validate(RegisterIndex_16, u16, "R9W, 0x5678", &.{ 0x66, 0x41, 0x81, 0xC1, 0x78, 0x56 }, add.r16_imm16, .R9W, 0x5678);
}

test "ADD 16 bit RIP-relative memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[RIP + 0x1234], AX",
        &.{ 0x66, 0x01, 0x05, 0x34, 0x12, 0x00, 0x00 },
        add.rm16_r16,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R9W, [RIP - 8]",
        &.{ 0x66, 0x44, 0x03, 0x0D, 0xF8, 0xFF, 0xFF, 0xFF },
        add.r16_rm16,
        .R9W,
        .{ .mem = .{ .ripRelative = -8 } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[RIP + 0x10], 0xBEEF",
        &.{ 0x66, 0x81, 0x05, 0x10, 0x00, 0x00, 0x00, 0xEF, 0xBE },
        add.rm16_imm16,
        .{ .mem = .{ .ripRelative = 0x10 } },
        0xBEEF,
    );
}

test "ADD 16 bit base-index64 memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[R8], AX",
        &.{ 0x66, 0x41, 0x01, 0x00 },
        add.rm16_r16,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .AX,
    );
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[R9 + 4], AX",
        &.{ 0x66, 0x41, 0x01, 0x41, 0x04 },
        add.rm16_r16,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .AX,
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[RAX + R10*2 - 4], 0x1234",
        &.{ 0x66, 0x42, 0x81, 0x44, 0x50, 0xFC, 0x34, 0x12 },
        add.rm16_imm16,
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
        0x1234,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [R8]",
        &.{ 0x66, 0x45, 0x03, 0x18 },
        add.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [R9 + 4]",
        &.{ 0x66, 0x45, 0x03, 0x59, 0x04 },
        add.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[RAX + R10*8 + 0x10], R11W",
        &.{ 0x66, 0x46, 0x01, 0x5C, 0xD0, 0x10 },
        add.rm16_r16,
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
        .R11W,
    );
}

test "ADD 16 bit base-index32 memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[EBX + ECX*2], AX",
        &.{ 0x66, 0x67, 0x01, 0x04, 0x4B },
        add.rm16_r16,
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
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [EBX + ECX*2]",
        &.{ 0x66, 0x67, 0x44, 0x03, 0x1C, 0x4B },
        add.r16_rm16,
        .R11W,
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
        RegisterMemory_16,
        RegisterIndex_16,
        "[R8D], AX",
        &.{ 0x66, 0x67, 0x41, 0x01, 0x00 },
        add.rm16_r16,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [R8D]",
        &.{ 0x66, 0x67, 0x45, 0x03, 0x18 },
        add.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[EBP], 0x1234",
        &.{ 0x66, 0x67, 0x81, 0x45, 0x00, 0x34, 0x12 },
        add.rm16_imm16,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x1234,
    );
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[ECX*4 + 0x1234], AX",
        &.{ 0x66, 0x67, 0x01, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        add.rm16_r16,
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
        .AX,
    );
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[addr32:0x1234], AX",
        &.{ 0x66, 0x67, 0x01, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.rm16_r16,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [addr32:0x1234]",
        &.{ 0x66, 0x67, 0x44, 0x03, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[addr32:0x1234], 0x1234",
        &.{ 0x66, 0x67, 0x81, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00, 0x34, 0x12 },
        add.rm16_imm16,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1234,
    );
}

test "ADD 16 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, add.r16_imm16(&writer, .AX, 0x1234));
}
