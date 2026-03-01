const std = @import("std");
const common = @import("common.zig");

const cmp = common.cmp;
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
    tested: fn (writer: *std.io.Writer, dest: Dest, source: Src) EncodingError!usize,
    dest: Dest,
    source: Src,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_impl(Dest, Src, name, expected, tested, dest, source);
}

test "CMP 8 bit forms" {
    try validate(RegisterMemory_8, RegisterIndex_8, "AL, CL", &.{ 0x38, 0xC8 }, cmp.rm8_r8, .{ .reg = .AL }, .CL);
    try validate(RegisterIndex_8, RegisterMemory_8, "AL, CL", &.{ 0x3A, 0xC1 }, cmp.r8_rm8, .AL, .{ .reg = .CL });
    try validate(RegisterMemory_8, u8, "AL, 0x7f", &.{ 0x80, 0xF8, 0x7F }, cmp.rm8_imm8, .{ .reg = .AL }, 0x7F);
    try validate(RegisterIndex_8, u8, "R9B, 0x01", &.{ 0x41, 0x80, 0xF9, 0x01 }, cmp.r8_imm8, .R9B, 0x01);
}

test "CMP 8 bit RIP-relative memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[RIP + 0x20], AL",
        &.{ 0x38, 0x05, 0x20, 0x00, 0x00, 0x00 },
        cmp.rm8_r8,
        .{ .mem = .{ .ripRelative = 0x20 } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "CL, [RIP - 4]",
        &.{ 0x3A, 0x0D, 0xFC, 0xFF, 0xFF, 0xFF },
        cmp.r8_rm8,
        .CL,
        .{ .mem = .{ .ripRelative = -4 } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[RIP + 0x20], 0x7F",
        &.{ 0x80, 0x3D, 0x20, 0x00, 0x00, 0x00, 0x7F },
        cmp.rm8_imm8,
        .{ .mem = .{ .ripRelative = 0x20 } },
        0x7F,
    );
}

test "CMP 8 bit invalid high register and REX combinations" {
    var buffer: [8]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.InvalidOperand, cmp.rm8_r8(&writer, .{ .reg = .AH }, .R8B));
    try std.testing.expectError(EncodingError.InvalidOperand, cmp.r8_rm8(&writer, .SPL, .{ .reg = .AH }));
    try std.testing.expectError(EncodingError.InvalidOperand, cmp.rm8_r8(&writer, .{ .reg = .SPL }, .AH));
    try std.testing.expectError(EncodingError.InvalidOperand, cmp.r8_rm8(&writer, .AH, .{ .reg = .R8B }));
}

test "CMP 8 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, cmp.rm8_r8(&writer, .{ .reg = .AL }, .CL));
}
