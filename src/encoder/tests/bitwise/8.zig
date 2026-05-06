const std = @import("std");
const common = @import("common.zig");

const bitand = common.bitand;
const bitor = common.bitor;
const bitxor = common.bitxor;
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

test "BITWISE 8 bit register and immediate forms" {
    try validate(RegisterMemory_8, RegisterIndex_8, "AND AL, CL", &.{ 0x20, 0xC8 }, bitand.rm8_r8, .{ .reg = .AL }, .CL);
    try validate(RegisterMemory_8, RegisterIndex_8, "OR AL, CL", &.{ 0x08, 0xC8 }, bitor.rm8_r8, .{ .reg = .AL }, .CL);
    try validate(RegisterMemory_8, RegisterIndex_8, "XOR AL, CL", &.{ 0x30, 0xC8 }, bitxor.rm8_r8, .{ .reg = .AL }, .CL);

    try validate(RegisterIndex_8, RegisterMemory_8, "AND AL, CL", &.{ 0x22, 0xC1 }, bitand.r8_rm8, .AL, .{ .reg = .CL });
    try validate(RegisterIndex_8, RegisterMemory_8, "OR AL, CL", &.{ 0x0A, 0xC1 }, bitor.r8_rm8, .AL, .{ .reg = .CL });
    try validate(RegisterIndex_8, RegisterMemory_8, "XOR AL, CL", &.{ 0x32, 0xC1 }, bitxor.r8_rm8, .AL, .{ .reg = .CL });

    try validate(RegisterMemory_8, u8, "AND AL, 0x7f", &.{ 0x80, 0xE0, 0x7F }, bitand.rm8_imm8, .{ .reg = .AL }, 0x7F);
    try validate(RegisterMemory_8, u8, "OR AL, 0x7f", &.{ 0x80, 0xC8, 0x7F }, bitor.rm8_imm8, .{ .reg = .AL }, 0x7F);
    try validate(RegisterMemory_8, u8, "XOR AL, 0x7f", &.{ 0x80, 0xF0, 0x7F }, bitxor.rm8_imm8, .{ .reg = .AL }, 0x7F);
}

test "BITWISE 8 bit RIP-relative memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "AND [RIP + 0x20], AL",
        &.{ 0x20, 0x05, 0x20, 0x00, 0x00, 0x00 },
        bitand.rm8_r8,
        .{ .mem = .{ .ripRelative = 0x20 } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "OR AL, [RIP - 4]",
        &.{ 0x0A, 0x05, 0xFC, 0xFF, 0xFF, 0xFF },
        bitor.r8_rm8,
        .AL,
        .{ .mem = .{ .ripRelative = -4 } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "XOR [RIP + 0x20], 0x7F",
        &.{ 0x80, 0x35, 0x20, 0x00, 0x00, 0x00, 0x7F },
        bitxor.rm8_imm8,
        .{ .mem = .{ .ripRelative = 0x20 } },
        0x7F,
    );
}

test "BITWISE 8 bit base-index64 memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "AND [R8], AL",
        &.{ 0x41, 0x20, 0x00 },
        bitand.rm8_r8,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "OR R11B, [R9 + 4]",
        &.{ 0x45, 0x0A, 0x59, 0x04 },
        bitor.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "XOR [RAX + R10*2 - 4], 0x42",
        &.{ 0x42, 0x80, 0x74, 0x50, 0xFC, 0x42 },
        bitxor.rm8_imm8,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{ .reg = .R10, .scale = .x2 },
                    .disp = -4,
                },
            },
        },
        0x42,
    );
}

test "BITWISE 8 bit base-index32 memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "AND [EBX + ECX*2], AL",
        &.{ 0x67, 0x20, 0x04, 0x4B },
        bitand.rm8_r8,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = .EBX,
                    .index = .{ .reg = .ECX, .scale = .x2 },
                },
            },
        },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "OR R11B, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x0A, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        bitor.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "XOR [addr32:0x1234], 0x44",
        &.{ 0x67, 0x80, 0x34, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44 },
        bitxor.rm8_imm8,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x44,
    );
}

test "BITWISE 8 bit invalid high register and REX combinations" {
    var buffer: [8]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.InvalidOperand, bitand.rm8_r8(&writer, .{ .reg = .AH }, .R8B));
    try std.testing.expectError(EncodingError.InvalidOperand, bitor.r8_rm8(&writer, .SPL, .{ .reg = .AH }));
}

test "BITWISE 8 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, bitxor.rm8_r8(&writer, .{ .reg = .AL }, .CL));
}
