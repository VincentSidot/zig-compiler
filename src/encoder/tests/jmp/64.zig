const std = @import("std");
const common = @import("common.zig");

const jmp = common.jmp;
const validate_impl = common.validate;
const validate_rel8_impl = common.validate_rel8;
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

fn validate_rel8(
    comptime name: []const u8,
    comptime expected: []const u8,
    disp: i8,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_rel8_impl(name, expected, disp);
}

fn validate_rel32(
    comptime name: []const u8,
    comptime expected: []const u8,
    disp: i32,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_rel32_impl(name, expected, disp);
}

test "JMP rel forms" {
    try validate_rel8("disp +0x7f", &.{ 0xEB, 0x7F }, 0x7F);
    try validate_rel8("disp -2", &.{ 0xEB, 0xFE }, -2);

    try validate_rel32("disp +0x1234", &.{ 0xE9, 0x34, 0x12, 0x00, 0x00 }, 0x1234);
    try validate_rel32("disp -6", &.{ 0xE9, 0xFA, 0xFF, 0xFF, 0xFF }, -6);
}

test "JMP patch_rel8 patches forward/backward targets" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var buffer = [_]u8{
        0xEB, 0x00, // jmp rel8 at 0
        0x90, 0x90, 0x90, 0x90, // filler
        0xEB, 0x00, // jmp rel8 at 6
    };

    try jmp.patch_rel8(buffer[0..], 0, 8);
    try std.testing.expectEqualSlices(u8, &.{0x06}, buffer[1..2]);

    try jmp.patch_rel8(buffer[0..], 6, 2);
    try std.testing.expectEqualSlices(u8, &.{0xFA}, buffer[7..8]);
}

test "JMP patch_rel32 patches forward/backward targets" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var buffer = [_]u8{
        0xE9, 0x00, 0x00, 0x00, 0x00, // jmp rel32 at 0
        0x90, 0x90, 0x90, // filler
        0xE9, 0x00, 0x00, 0x00, 0x00, // jmp rel32 at 8
    };

    try jmp.patch_rel32(buffer[0..], 0, 0x20);
    try std.testing.expectEqualSlices(u8, &.{ 0x1B, 0x00, 0x00, 0x00 }, buffer[1..5]);

    try jmp.patch_rel32(buffer[0..], 8, 4);
    try std.testing.expectEqualSlices(u8, &.{ 0xF7, 0xFF, 0xFF, 0xFF }, buffer[9..13]);
}

test "JMP patch_rel8 returns errors" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var short = [_]u8{0xEB};
    try std.testing.expectError(EncodingError.InvalidPatchAddress, jmp.patch_rel8(short[0..], 0, 0));

    var rel8 = [_]u8{ 0xEB, 0x00 };
    try std.testing.expectError(EncodingError.InvalidDisplacement, jmp.patch_rel8(rel8[0..], 0, 130));
}

test "JMP patch_rel32 returns errors" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var short = [_]u8{ 0xE9, 0x00, 0x00, 0x00 };
    try std.testing.expectError(EncodingError.InvalidPatchAddress, jmp.patch_rel32(short[0..], 0, 0));

    var rel32 = [_]u8{ 0xE9, 0x00, 0x00, 0x00, 0x00 };
    const too_far_target = @as(usize, @intCast(@as(i64, std.math.maxInt(i32)) + 6));
    try std.testing.expectError(
        EncodingError.InvalidDisplacement,
        jmp.patch_rel32(rel32[0..], 0, too_far_target),
    );
}

test "JMP register forms" {
    try validate(RegisterIndex_64, "RAX", &.{ 0xFF, 0xE0 }, jmp.r64, .RAX);
    try validate(RegisterIndex_64, "R9", &.{ 0x41, 0xFF, 0xE1 }, jmp.r64, .R9);
}

test "JMP rm64 memory forms" {
    try validate(RegisterMemory_64, "[RAX]", &.{ 0xFF, 0x20 }, jmp.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_64, "[RAX + 0x20]", &.{ 0xFF, 0x60, 0x20 }, jmp.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = 0x20 } } });
    try validate(RegisterMemory_64, "[R12]", &.{ 0x41, 0xFF, 0x24, 0x24 }, jmp.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .R12 } } });
    try validate(RegisterMemory_64, "[R13]", &.{ 0x41, 0xFF, 0x65, 0x00 }, jmp.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .R13 } } });
    try validate(RegisterMemory_64, "[RIP + 0x20]", &.{ 0xFF, 0x25, 0x20, 0x00, 0x00, 0x00 }, jmp.rm64, .{ .mem = .{ .ripRelative = 0x20 } });
    try validate(RegisterMemory_64, "[RCX*4 + 0x1234]", &.{ 0xFF, 0x24, 0x8D, 0x34, 0x12, 0x00, 0x00 }, jmp.rm64, .{
        .mem = .{
            .baseIndex64 = .{
                .base = null,
                .index = .{ .reg = .RCX, .scale = .x4 },
                .disp = 0x1234,
            },
        },
    });
}

test "JMP address-size override forms" {
    try validate(RegisterMemory_64, "[R8D]", &.{ 0x67, 0x41, 0xFF, 0x20 }, jmp.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } });
    try validate(RegisterMemory_64, "[EBP]", &.{ 0x67, 0xFF, 0x65, 0x00 }, jmp.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } });
    try validate(RegisterMemory_64, "[addr32:0x1234]", &.{ 0x67, 0xFF, 0x24, 0x25, 0x34, 0x12, 0x00, 0x00 }, jmp.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });
}

test "JMP writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.WriterError, jmp.rel8(&writer, -1));
    try std.testing.expectError(EncodingError.WriterError, jmp.r64(&writer, .RAX));
}
