const std = @import("std");
const common = @import("common.zig");

const lea = common.lea;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_32 = common.RegisterIndex_32;
const RegisterMemory_32 = common.RegisterMemory_32;

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

test "LEA 32 bit memory forms" {
    try validate(RegisterIndex_32, RegisterMemory_32, "EAX, [RIP+0x1234]", &.{ 0x8D, 0x05, 0x34, 0x12, 0x00, 0x00 }, lea.r32_m, .EAX, .{ .mem = .{ .ripRelative = 0x1234 } });
    try validate(RegisterIndex_32, RegisterMemory_32, "R11D, [R9+4]", &.{ 0x45, 0x8D, 0x59, 0x04 }, lea.r32_m, .R11D, .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } });
    try validate(RegisterIndex_32, RegisterMemory_32, "R11D, [addr32:0x1234]", &.{ 0x67, 0x44, 0x8D, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 }, lea.r32_m, .R11D, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });
}

test "LEA 32 bit invalid reg source" {
    var buffer: [8]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.InvalidOperand, lea.r32_m(&writer, .EAX, .{ .reg = .ECX }));
}

test "LEA 32 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.WriterError, lea.r32_m(&writer, .EAX, .{ .mem = .{ .ripRelative = 0x10 } }));
}
