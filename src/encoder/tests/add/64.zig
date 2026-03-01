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
    tested: fn (writer: *std.io.Writer, dest: Dest, source: Src) EncodingError!usize,
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

test "ADD 64 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, add.r64_imm32(&writer, .RAX, 1));
}
