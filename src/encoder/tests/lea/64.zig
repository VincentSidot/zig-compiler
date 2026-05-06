const std = @import("std");
const common = @import("common.zig");

const lea = common.lea;
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

test "LEA 64 bit memory forms" {
    try validate(RegisterIndex_64, RegisterMemory_64, "RAX, [RAX]", &.{ 0x48, 0x8D, 0x00 }, lea.r64_m, .RAX, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterIndex_64, RegisterMemory_64, "R11, [RIP+0x1234]", &.{ 0x4C, 0x8D, 0x1D, 0x34, 0x12, 0x00, 0x00 }, lea.r64_m, .R11, .{ .mem = .{ .ripRelative = 0x1234 } });
    try validate(RegisterIndex_64, RegisterMemory_64, "RAX, [R12]", &.{ 0x49, 0x8D, 0x04, 0x24 }, lea.r64_m, .RAX, .{ .mem = .{ .baseIndex64 = .{ .base = .R12 } } });
    try validate(RegisterIndex_64, RegisterMemory_64, "RAX, [R13]", &.{ 0x49, 0x8D, 0x45, 0x00 }, lea.r64_m, .RAX, .{ .mem = .{ .baseIndex64 = .{ .base = .R13 } } });
    try validate(RegisterIndex_64, RegisterMemory_64, "RAX, [RCX*4 + 0x1234]", &.{ 0x48, 0x8D, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 }, lea.r64_m, .RAX, .{ .mem = .{ .baseIndex64 = .{ .base = null, .index = .{ .reg = .RCX, .scale = .x4 }, .disp = 0x1234 } } });
    try validate(RegisterIndex_64, RegisterMemory_64, "R11, [addr32:0x1234]", &.{ 0x67, 0x4C, 0x8D, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 }, lea.r64_m, .R11, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });
}

test "LEA 64 bit invalid reg source" {
    var buffer: [8]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.InvalidOperand, lea.r64_m(&writer, .RAX, .{ .reg = .RCX }));
}

test "LEA 64 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.WriterError, lea.r64_m(&writer, .RAX, .{ .mem = .{ .ripRelative = 0x10 } }));
}
