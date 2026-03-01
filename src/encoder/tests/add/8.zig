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
    tested: fn (writer: *std.io.Writer, dest: Dest, source: Src) EncodingError!usize,
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

test "ADD 8 bit invalid high register and REX combinations" {
    var buffer: [8]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

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
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, add.rm8_r8(&writer, .{ .reg = .AL }, .CL));
}
