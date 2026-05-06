const std = @import("std");
const common = @import("common.zig");

const jcc = common.jcc;
const Condition = common.Condition;
const validate_rel8_impl = common.validate_rel8;
const validate_rel32_impl = common.validate_rel32;
const validate_rel8_cond_impl = common.validate_rel8_cond;
const validate_rel32_cond_impl = common.validate_rel32_cond;
const EncodingError = common.EncodingError;

pub var validate_calls = std.atomic.Value(usize).init(0);

fn validate_rel8(
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn (writer: *std.Io.Writer, disp: i8) EncodingError!usize,
    disp: i8,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_rel8_impl(name, expected, tested, disp);
}

fn validate_rel32(
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn (writer: *std.Io.Writer, disp: i32) EncodingError!usize,
    disp: i32,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_rel32_impl(name, expected, tested, disp);
}

fn validate_rel8_cond(
    comptime name: []const u8,
    comptime expected: []const u8,
    condition: Condition,
    disp: i8,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_rel8_cond_impl(name, expected, condition, disp);
}

fn validate_rel32_cond(
    comptime name: []const u8,
    comptime expected: []const u8,
    condition: Condition,
    disp: i32,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_rel32_cond_impl(name, expected, condition, disp);
}

test "JCC rel8 convenience wrappers" {
    try validate_rel8("jz +0x7f", &.{ 0x74, 0x7F }, jcc.jz_rel8, 0x7F);
    try validate_rel8("jnz -2", &.{ 0x75, 0xFE }, jcc.jnz_rel8, -2);
    try validate_rel8("jl +5", &.{ 0x7C, 0x05 }, jcc.jl_rel8, 5);
    try validate_rel8("jg -5", &.{ 0x7F, 0xFB }, jcc.jg_rel8, -5);
    try validate_rel8("jb +1", &.{ 0x72, 0x01 }, jcc.jb_rel8, 1);
    try validate_rel8("ja +1", &.{ 0x77, 0x01 }, jcc.ja_rel8, 1);
}

test "JCC rel32 convenience wrappers" {
    try validate_rel32("jz +0x1234", &.{ 0x0F, 0x84, 0x34, 0x12, 0x00, 0x00 }, jcc.jz_rel32, 0x1234);
    try validate_rel32("jnz -6", &.{ 0x0F, 0x85, 0xFA, 0xFF, 0xFF, 0xFF }, jcc.jnz_rel32, -6);
    try validate_rel32("jl +0x20", &.{ 0x0F, 0x8C, 0x20, 0x00, 0x00, 0x00 }, jcc.jl_rel32, 0x20);
    try validate_rel32("jg +0x20", &.{ 0x0F, 0x8F, 0x20, 0x00, 0x00, 0x00 }, jcc.jg_rel32, 0x20);
    try validate_rel32("jle +0x20", &.{ 0x0F, 0x8E, 0x20, 0x00, 0x00, 0x00 }, jcc.jle_rel32, 0x20);
    try validate_rel32("jge +0x20", &.{ 0x0F, 0x8D, 0x20, 0x00, 0x00, 0x00 }, jcc.jge_rel32, 0x20);
}

test "JCC generic condition forms" {
    try validate_rel8_cond("ns -1", &.{ 0x79, 0xFF }, .ns, -1);
    try validate_rel32_cond("a +0x10", &.{ 0x0F, 0x87, 0x10, 0x00, 0x00, 0x00 }, .a, 0x10);
}

test "JCC patch_rel8 patches forward/backward targets" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var buffer = [_]u8{
        0x74, 0x00, // jz rel8 at 0
        0x90, 0x90, 0x90, 0x90, // filler
        0x75, 0x00, // jnz rel8 at 6
    };

    try jcc.patch_rel8(buffer[0..], 0, 8);
    try std.testing.expectEqualSlices(u8, &.{0x06}, buffer[1..2]);

    try jcc.patch_rel8(buffer[0..], 6, 2);
    try std.testing.expectEqualSlices(u8, &.{0xFA}, buffer[7..8]);
}

test "JCC patch_rel32 patches forward/backward targets" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var buffer = [_]u8{
        0x0F, 0x84, 0x00, 0x00, 0x00, 0x00, // jz rel32 at 0
        0x90, 0x90, // filler
        0x0F, 0x85, 0x00, 0x00, 0x00, 0x00, // jnz rel32 at 8
    };

    try jcc.patch_rel32(buffer[0..], 0, 0x20);
    try std.testing.expectEqualSlices(u8, &.{ 0x1A, 0x00, 0x00, 0x00 }, buffer[2..6]);

    try jcc.patch_rel32(buffer[0..], 8, 4);
    try std.testing.expectEqualSlices(u8, &.{ 0xF6, 0xFF, 0xFF, 0xFF }, buffer[10..14]);
}

test "JCC patch_rel8 returns errors" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var short = [_]u8{0x74};
    try std.testing.expectError(EncodingError.InvalidPatchAddress, jcc.patch_rel8(short[0..], 0, 0));

    var rel8 = [_]u8{ 0x74, 0x00 };
    try std.testing.expectError(EncodingError.InvalidDisplacement, jcc.patch_rel8(rel8[0..], 0, 130));
}

test "JCC patch_rel32 returns errors" {
    _ = validate_calls.fetchAdd(1, .monotonic);

    var short = [_]u8{ 0x0F, 0x84, 0x00, 0x00, 0x00 };
    try std.testing.expectError(EncodingError.InvalidPatchAddress, jcc.patch_rel32(short[0..], 0, 0));

    var rel32 = [_]u8{ 0x0F, 0x84, 0x00, 0x00, 0x00, 0x00 };
    const too_far_target = @as(usize, @intCast(@as(i64, std.math.maxInt(i32)) + 7));
    try std.testing.expectError(
        EncodingError.InvalidDisplacement,
        jcc.patch_rel32(rel32[0..], 0, too_far_target),
    );
}

test "JCC writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.WriterError, jcc.jz_rel8(&writer, 1));
    try std.testing.expectError(EncodingError.WriterError, jcc.jz_rel32(&writer, 1));
}
