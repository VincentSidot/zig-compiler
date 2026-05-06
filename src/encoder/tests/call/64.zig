const std = @import("std");
const common = @import("common.zig");

const call = common.call;
const validate_impl = common.validate;
const validate_rel32_impl = common.validate_rel32;
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

fn validate_rel32(
    comptime name: []const u8,
    comptime expected: []const u8,
    disp: i32,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_rel32_impl(name, expected, disp);
}

test "CALL rel32 forms" {
    try validate_rel32("disp +0x1234", &.{ 0xE8, 0x34, 0x12, 0x00, 0x00 }, 0x1234);
    try validate_rel32("disp -6", &.{ 0xE8, 0xFA, 0xFF, 0xFF, 0xFF }, -6);
}

test "CALL patch_rel32 patches forward/backward targets" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var buffer = [_]u8{
        0xE8, 0x00, 0x00, 0x00, 0x00, // call at 0
        0x90, 0x90, 0x90, 0x90, 0x90, // filler
        0xE8, 0x00, 0x00, 0x00, 0x00, // call at 10
    };

    try call.patch_rel32(buffer[0..], 0, 0x20);
    try std.testing.expectEqualSlices(u8, &.{ 0x1B, 0x00, 0x00, 0x00 }, buffer[1..5]);

    try call.patch_rel32(buffer[0..], 10, 2);
    try std.testing.expectEqualSlices(u8, &.{ 0xF3, 0xFF, 0xFF, 0xFF }, buffer[11..15]);
}

test "CALL patch_rel32 returns InvalidPatchAddress" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var buffer = [_]u8{ 0xE8, 0x00, 0x00, 0x00 };
    try std.testing.expectError(EncodingError.InvalidPatchAddress, call.patch_rel32(buffer[0..], 0, 0));
}

test "CALL patch_rel32 returns InvalidDisplacement" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var buffer = [_]u8{ 0xE8, 0x00, 0x00, 0x00, 0x00 };
    const too_far_target = @as(usize, @intCast(@as(i64, std.math.maxInt(i32)) + 6));
    try std.testing.expectError(
        EncodingError.InvalidDisplacement,
        call.patch_rel32(buffer[0..], 0, too_far_target),
    );
}

test "CALL register forms" {
    try validate(RegisterIndex_64, "RAX", &.{ 0xFF, 0xD0 }, call.r64, .RAX);
    try validate(RegisterIndex_64, "R9", &.{ 0x41, 0xFF, 0xD1 }, call.r64, .R9);
}

test "CALL memory forms" {
    try validate(RegisterMemory_64, "[RAX]", &.{ 0xFF, 0x10 }, call.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_64, "[RAX + 0x20]", &.{ 0xFF, 0x50, 0x20 }, call.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = 0x20 } } });
    try validate(RegisterMemory_64, "[R12]", &.{ 0x41, 0xFF, 0x14, 0x24 }, call.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .R12 } } });
    try validate(RegisterMemory_64, "[R13]", &.{ 0x41, 0xFF, 0x55, 0x00 }, call.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .R13 } } });
    try validate(RegisterMemory_64, "[RIP + 0x20]", &.{ 0xFF, 0x15, 0x20, 0x00, 0x00, 0x00 }, call.rm64, .{ .mem = .{ .ripRelative = 0x20 } });
    try validate(RegisterMemory_64, "[RCX*4 + 0x1234]", &.{ 0xFF, 0x14, 0x8D, 0x34, 0x12, 0x00, 0x00 }, call.rm64, .{
        .mem = .{
            .baseIndex64 = .{
                .base = null,
                .index = .{ .reg = .RCX, .scale = .x4 },
                .disp = 0x1234,
            },
        },
    });
}

test "CALL address-size override forms" {
    try validate(RegisterMemory_64, "[R8D]", &.{ 0x67, 0x41, 0xFF, 0x10 }, call.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } });
    try validate(RegisterMemory_64, "[EBP]", &.{ 0x67, 0xFF, 0x55, 0x00 }, call.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } });
    try validate(RegisterMemory_64, "[addr32:0x1234]", &.{ 0x67, 0xFF, 0x14, 0x25, 0x34, 0x12, 0x00, 0x00 }, call.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });
}

test "CALL writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.WriterError, call.rel32(&writer, 0x1234));
    try std.testing.expectError(EncodingError.WriterError, call.r64(&writer, .RAX));
}
