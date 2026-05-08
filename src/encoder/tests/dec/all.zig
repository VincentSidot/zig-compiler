const std = @import("std");
const common = @import("common.zig");

const dec = common.dec;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterMemory_8 = common.RegisterMemory_8;
const RegisterMemory_16 = common.RegisterMemory_16;
const RegisterMemory_32 = common.RegisterMemory_32;
const RegisterMemory_64 = common.RegisterMemory_64;

pub var validate_calls = std.atomic.Value(usize).init(0);

fn validate(
    comptime Dest: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn (writer: *std.Io.Writer, dest: Dest) EncodingError!usize,
    dest: Dest,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_impl(Dest, name, expected, tested, dest);
}

test "DEC register forms" {
    try validate(RegisterMemory_8, "AL", &.{ 0xFE, 0xC8 }, dec.rm8, .{ .reg = .AL });
    try validate(RegisterMemory_8, "SPL", &.{ 0x40, 0xFE, 0xCC }, dec.rm8, .{ .reg = .SPL });
    try validate(RegisterMemory_8, "R9B", &.{ 0x41, 0xFE, 0xC9 }, dec.rm8, .{ .reg = .R9B });

    try validate(RegisterMemory_16, "AX", &.{ 0x66, 0xFF, 0xC8 }, dec.rm16, .{ .reg = .AX });
    try validate(RegisterMemory_16, "R9W", &.{ 0x66, 0x41, 0xFF, 0xC9 }, dec.rm16, .{ .reg = .R9W });

    try validate(RegisterMemory_32, "EAX", &.{ 0xFF, 0xC8 }, dec.rm32, .{ .reg = .EAX });
    try validate(RegisterMemory_32, "R9D", &.{ 0x41, 0xFF, 0xC9 }, dec.rm32, .{ .reg = .R9D });

    try validate(RegisterMemory_64, "RAX", &.{ 0x48, 0xFF, 0xC8 }, dec.rm64, .{ .reg = .RAX });
    try validate(RegisterMemory_64, "R9", &.{ 0x49, 0xFF, 0xC9 }, dec.rm64, .{ .reg = .R9 });
}

test "DEC memory forms" {
    try validate(RegisterMemory_8, "[RAX]", &.{ 0xFE, 0x08 }, dec.rm8, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_8, "[R9]", &.{ 0x41, 0xFE, 0x09 }, dec.rm8, .{ .mem = .{ .baseIndex64 = .{ .base = .R9 } } });

    try validate(RegisterMemory_16, "[RAX]", &.{ 0x66, 0xFF, 0x08 }, dec.rm16, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_16, "[addr32:0x1234]", &.{ 0x66, 0x67, 0xFF, 0x0C, 0x25, 0x34, 0x12, 0x00, 0x00 }, dec.rm16, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });

    try validate(RegisterMemory_32, "[RAX]", &.{ 0xFF, 0x08 }, dec.rm32, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_32, "[addr32:0x1234]", &.{ 0x67, 0xFF, 0x0C, 0x25, 0x34, 0x12, 0x00, 0x00 }, dec.rm32, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });

    try validate(RegisterMemory_64, "[RAX]", &.{ 0x48, 0xFF, 0x08 }, dec.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_64, "[R9]", &.{ 0x49, 0xFF, 0x09 }, dec.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .R9 } } });
}

test "DEC writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.WriterError, dec.rm8(&writer, .{ .reg = .AL }));
}
