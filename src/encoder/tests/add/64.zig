const std = @import("std");
const common = @import("common.zig");

const add = common.add;
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
    tested: fn (writer: *std.Io.Writer, dest: Dest, source: Src) EncodingError!usize,
    dest: Dest,
    source: Src,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_impl(Dest, Src, name, expected, tested, dest, source);
}

test "ADD 64 bit register and memory forms" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RAX], RCX",
        &.{ 0x48, 0x01, 0x08 },
        add.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } },
        .RCX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "R11, [RIP+0x1234]",
        &.{ 0x4C, 0x03, 0x1D, 0x34, 0x12, 0x00, 0x00 },
        add.r64_rm64,
        .R11,
        .{ .mem = .{ .ripRelative = 0x1234 } },
    );
}

test "ADD 64 bit immediate forms" {
    try validate(
        RegisterMemory_64,
        u32,
        "RAX, 1",
        &.{ 0x48, 0x81, 0xC0, 0x01, 0x00, 0x00, 0x00 },
        add.rm64_imm32,
        .{ .reg = .RAX },
        1,
    );
    try validate(
        RegisterIndex_64,
        u32,
        "R9, 0x11223344",
        &.{ 0x49, 0x81, 0xC1, 0x44, 0x33, 0x22, 0x11 },
        add.r64_imm32,
        .R9,
        0x1122_3344,
    );
}

test "ADD 64 bit RIP-relative memory" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RIP + 0x1234], RAX",
        &.{ 0x48, 0x01, 0x05, 0x34, 0x12, 0x00, 0x00 },
        add.rm64_r64,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "R9, [RIP - 24]",
        &.{ 0x4C, 0x03, 0x0D, 0xE8, 0xFF, 0xFF, 0xFF },
        add.r64_rm64,
        .R9,
        .{ .mem = .{ .ripRelative = -24 } },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[RIP + 0x1234], 0x89AB_CDEF",
        &.{ 0x48, 0x81, 0x05, 0x34, 0x12, 0x00, 0x00, 0xEF, 0xCD, 0xAB, 0x89 },
        add.rm64_imm32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        0x89AB_CDEF,
    );
}

test "ADD 64 bit absolute disp32 memory (no base/index)" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[0x1234], RAX",
        &.{ 0x48, 0x01, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.rm64_r64,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = null,
                    .index = null,
                    .disp = 0x1234,
                },
            },
        },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "R11, [0x1234]",
        &.{ 0x4C, 0x03, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.r64_rm64,
        .R11,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = null,
                    .index = null,
                    .disp = 0x1234,
                },
            },
        },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[0x1234], 0x11223344",
        &.{ 0x48, 0x81, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        add.rm64_imm32,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = null,
                    .index = null,
                    .disp = 0x1234,
                },
            },
        },
        0x1122_3344,
    );
}

test "ADD 64 bit base-index64 memory" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[R8], RAX",
        &.{ 0x49, 0x01, 0x00 },
        add.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .RAX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[R9 + 4], RAX",
        &.{ 0x49, 0x01, 0x41, 0x04 },
        add.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .RAX,
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[RAX + R10*2 - 4], 0x12345678",
        &.{ 0x4A, 0x81, 0x44, 0x50, 0xFC, 0x78, 0x56, 0x34, 0x12 },
        add.rm64_imm32,
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
        0x1234_5678,
    );

    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "RAX, [R8]",
        &.{ 0x49, 0x03, 0x00 },
        add.r64_rm64,
        .RAX,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "R11, [R9 + 4]",
        &.{ 0x4D, 0x03, 0x59, 0x04 },
        add.r64_rm64,
        .R11,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RAX + R10*8 + 0x10], R11",
        &.{ 0x4E, 0x01, 0x5C, 0xD0, 0x10 },
        add.rm64_r64,
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
        .R11,
    );
}

test "ADD 64 bit base-index32 memory" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[EBX + ECX*2], RAX",
        &.{ 0x67, 0x48, 0x01, 0x04, 0x4B },
        add.rm64_r64,
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
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "RAX, [EBX + ECX*2]",
        &.{ 0x67, 0x48, 0x03, 0x04, 0x4B },
        add.r64_rm64,
        .RAX,
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
        RegisterMemory_64,
        RegisterIndex_64,
        "[R8D], RAX",
        &.{ 0x67, 0x49, 0x01, 0x00 },
        add.rm64_r64,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "RAX, [R8D]",
        &.{ 0x67, 0x49, 0x03, 0x00 },
        add.r64_rm64,
        .RAX,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[EBP], 0x11223344",
        &.{ 0x67, 0x48, 0x81, 0x45, 0x00, 0x44, 0x33, 0x22, 0x11 },
        add.rm64_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x1122_3344,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[ECX*4 + 0x1234], RAX",
        &.{ 0x67, 0x48, 0x01, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        add.rm64_r64,
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
        .RAX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[addr32:0x1234], RAX",
        &.{ 0x67, 0x48, 0x01, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.rm64_r64,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "R11, [addr32:0x1234]",
        &.{ 0x67, 0x4C, 0x03, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.r64_rm64,
        .R11,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[addr32:0x1234], 0x11223344",
        &.{ 0x67, 0x48, 0x81, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        add.rm64_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );
}

test "ADD 64 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, add.r64_imm32(&writer, .RAX, 1));
}
