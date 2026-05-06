const std = @import("std");
const common = @import("common.zig");

const pop = common.pop;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_64 = common.RegisterIndex_64;
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

test "POP r64 forms" {
    try validate(RegisterIndex_64, "RAX", &.{0x58}, pop.r64, .RAX);
    try validate(RegisterIndex_64, "RCX", &.{0x59}, pop.r64, .RCX);
    try validate(RegisterIndex_64, "R9", &.{ 0x41, 0x59 }, pop.r64, .R9);
    try validate(RegisterIndex_64, "R15", &.{ 0x41, 0x5F }, pop.r64, .R15);
}

test "POP rm64 memory forms" {
    try validate(RegisterMemory_64, "[RAX]", &.{ 0x8F, 0x00 }, pop.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_64, "[RAX + 0x20]", &.{ 0x8F, 0x40, 0x20 }, pop.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = 0x20 } } });
    try validate(RegisterMemory_64, "[R12]", &.{ 0x41, 0x8F, 0x04, 0x24 }, pop.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .R12 } } });
    try validate(RegisterMemory_64, "[R13]", &.{ 0x41, 0x8F, 0x45, 0x00 }, pop.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .R13 } } });
    try validate(RegisterMemory_64, "[RIP + 0x20]", &.{ 0x8F, 0x05, 0x20, 0x00, 0x00, 0x00 }, pop.rm64, .{ .mem = .{ .ripRelative = 0x20 } });
    try validate(RegisterMemory_64, "[RCX*4 + 0x1234]", &.{ 0x8F, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 }, pop.rm64, .{
        .mem = .{
            .baseIndex64 = .{
                .base = null,
                .index = .{ .reg = .RCX, .scale = .x4 },
                .disp = 0x1234,
            },
        },
    });
}

test "POP address-size override forms" {
    try validate(RegisterMemory_64, "[R8D]", &.{ 0x67, 0x41, 0x8F, 0x00 }, pop.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } });
    try validate(RegisterMemory_64, "[EBP]", &.{ 0x67, 0x8F, 0x45, 0x00 }, pop.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } });
    try validate(RegisterMemory_64, "[addr32:0x1234]", &.{ 0x67, 0x8F, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 }, pop.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });
}

test "POP writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.WriterError, pop.r64(&writer, .RAX));
    try std.testing.expectError(EncodingError.WriterError, pop.rm64(&writer, .{ .reg = .RAX }));
}
