const std = @import("std");
const common = @import("common.zig");

const sub = common.sub;
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

test "SUB 8 bit register and immediate forms" {
    try validate(RegisterMemory_8, RegisterIndex_8, "AL, CL", &.{ 0x28, 0xC8 }, sub.rm8_r8, .{ .reg = .AL }, .CL);
    try validate(RegisterMemory_8, RegisterIndex_8, "R8B, R9B", &.{ 0x45, 0x28, 0xC8 }, sub.rm8_r8, .{ .reg = .R8B }, .R9B);
    try validate(RegisterIndex_8, RegisterMemory_8, "AL, CL", &.{ 0x2A, 0xC1 }, sub.r8_rm8, .AL, .{ .reg = .CL });

    try validate(RegisterMemory_8, u8, "AL, 0x7f", &.{ 0x80, 0xE8, 0x7F }, sub.rm8_imm8, .{ .reg = .AL }, 0x7F);
    try validate(RegisterIndex_8, u8, "R9B, 0x01", &.{ 0x41, 0x80, 0xE9, 0x01 }, sub.r8_imm8, .R9B, 0x01);
}

test "SUB 8 bit RIP-relative memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[RIP + 0x12345678], AL",
        &.{ 0x28, 0x05, 0x78, 0x56, 0x34, 0x12 },
        sub.rm8_r8,
        .{ .mem = .{ .ripRelative = 0x1234_5678 } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "CL, [RIP - 4]",
        &.{ 0x2A, 0x0D, 0xFC, 0xFF, 0xFF, 0xFF },
        sub.r8_rm8,
        .CL,
        .{ .mem = .{ .ripRelative = -4 } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[RIP + 0x20], 0x7F",
        &.{ 0x80, 0x2D, 0x20, 0x00, 0x00, 0x00, 0x7F },
        sub.rm8_imm8,
        .{ .mem = .{ .ripRelative = 0x20 } },
        0x7F,
    );
}

test "SUB 8 bit base-index64 memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[R8], AL",
        &.{ 0x41, 0x28, 0x00 },
        sub.rm8_r8,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .AL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[R9 + 4], AL",
        &.{ 0x41, 0x28, 0x41, 0x04 },
        sub.rm8_r8,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .AL,
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[RAX + R10*2 - 4], 0x42",
        &.{ 0x42, 0x80, 0x6C, 0x50, 0xFC, 0x42 },
        sub.rm8_imm8,
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
        &.{ 0x45, 0x2A, 0x18 },
        sub.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
}

test "SUB 8 bit base-index32 memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[EBX + ECX*2], AL",
        &.{ 0x67, 0x28, 0x04, 0x4B },
        sub.rm8_r8,
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
        "R11B, [R8D]",
        &.{ 0x67, 0x45, 0x2A, 0x18 },
        sub.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[EBP], 0x44",
        &.{ 0x67, 0x80, 0x6D, 0x00, 0x44 },
        sub.rm8_imm8,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x44,
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[addr32:0x1234], 0x44",
        &.{ 0x67, 0x80, 0x2C, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44 },
        sub.rm8_imm8,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x44,
    );
}

test "SUB 8 bit invalid high register and REX combinations" {
    var buffer: [8]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.InvalidOperand, sub.rm8_r8(&writer, .{ .reg = .AH }, .R8B));
    try std.testing.expectError(EncodingError.InvalidOperand, sub.r8_rm8(&writer, .SPL, .{ .reg = .AH }));
}

test "SUB 8 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, sub.rm8_r8(&writer, .{ .reg = .AL }, .CL));
}
