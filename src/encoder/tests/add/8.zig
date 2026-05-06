const std = @import("std");
const common = @import("common.zig");

const add = common.add;
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
    tested: fn (writer: *std.Io.Writer, dest: Dest, source: Src) EncodingError!usize,
    dest: Dest,
    source: Src,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_impl(Dest, Src, name, expected, tested, dest, source);
}

test "ADD 8 bit register and memory forms" {
    try validate(RegisterMemory_8, RegisterIndex_8, "AL, CL", &.{ 0x00, 0xC8 }, add.rm8_r8, .{ .reg = .AL }, .CL);
    try validate(RegisterMemory_8, RegisterIndex_8, "R8B, R9B", &.{ 0x45, 0x00, 0xC8 }, add.rm8_r8, .{ .reg = .R8B }, .R9B);
    try validate(RegisterIndex_8, RegisterMemory_8, "AL, CL", &.{ 0x02, 0xC1 }, add.r8_rm8, .AL, .{ .reg = .CL });
}

test "ADD 8 bit immediate forms" {
    try validate(RegisterMemory_8, u8, "AL, 0x7f", &.{ 0x80, 0xC0, 0x7F }, add.rm8_imm8, .{ .reg = .AL }, 0x7F);
    try validate(RegisterIndex_8, u8, "R9B, 0x01", &.{ 0x41, 0x80, 0xC1, 0x01 }, add.r8_imm8, .R9B, 0x01);
}

test "ADD 8 bit RIP-relative memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[RIP + 0x12345678], AL",
        &.{ 0x00, 0x05, 0x78, 0x56, 0x34, 0x12 },
        add.rm8_r8,
        .{ .mem = .{ .ripRelative = 0x1234_5678 } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "CL, [RIP - 4]",
        &.{ 0x02, 0x0D, 0xFC, 0xFF, 0xFF, 0xFF },
        add.r8_rm8,
        .CL,
        .{ .mem = .{ .ripRelative = -4 } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[RIP + 0x20], 0x7F",
        &.{ 0x80, 0x05, 0x20, 0x00, 0x00, 0x00, 0x7F },
        add.rm8_imm8,
        .{ .mem = .{ .ripRelative = 0x20 } },
        0x7F,
    );
}

test "ADD 8 bit base-index64 memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[R8], AL",
        &.{ 0x41, 0x00, 0x00 },
        add.rm8_r8,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .AL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[R9 + 4], AL",
        &.{ 0x41, 0x00, 0x41, 0x04 },
        add.rm8_r8,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .AL,
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[RAX + R10*2 - 4], 0x42",
        &.{ 0x42, 0x80, 0x44, 0x50, 0xFC, 0x42 },
        add.rm8_imm8,
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
        0x42,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [R8]",
        &.{ 0x45, 0x02, 0x18 },
        add.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [R9 + 4]",
        &.{ 0x45, 0x02, 0x59, 0x04 },
        add.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[RAX + R10*8 + 0x10], R11B",
        &.{ 0x46, 0x00, 0x5C, 0xD0, 0x10 },
        add.rm8_r8,
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
        .R11B,
    );
}

test "ADD 8 bit base-index32 memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[EBX + ECX*2], AL",
        &.{ 0x67, 0x00, 0x04, 0x4B },
        add.rm8_r8,
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
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [EBX + ECX*2]",
        &.{ 0x67, 0x44, 0x02, 0x1C, 0x4B },
        add.r8_rm8,
        .R11B,
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
        RegisterMemory_8,
        RegisterIndex_8,
        "[R8D], AL",
        &.{ 0x67, 0x41, 0x00, 0x00 },
        add.rm8_r8,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [R8D]",
        &.{ 0x67, 0x45, 0x02, 0x18 },
        add.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[EBP], 0x44",
        &.{ 0x67, 0x80, 0x45, 0x00, 0x44 },
        add.rm8_imm8,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x44,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[ECX*4 + 0x1234], AL",
        &.{ 0x67, 0x00, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        add.rm8_r8,
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
        .AL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[addr32:0x1234], AL",
        &.{ 0x67, 0x00, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.rm8_r8,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x02, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        add.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[addr32:0x1234], 0x44",
        &.{ 0x67, 0x80, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44 },
        add.rm8_imm8,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x44,
    );
}

test "ADD 8 bit invalid high register and REX combinations" {
    var buffer: [8]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(
        EncodingError.InvalidOperand,
        add.rm8_r8(&writer, .{ .reg = .AH }, .R8B),
    );
    try std.testing.expectError(
        EncodingError.InvalidOperand,
        add.r8_rm8(&writer, .SPL, .{ .reg = .AH }),
    );
}

test "ADD 8 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, add.rm8_r8(&writer, .{ .reg = .AL }, .CL));
}
