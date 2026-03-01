const std = @import("std");
const common = @import("common.zig");

const bitand = common.bitand;
const bitor = common.bitor;
const bitxor = common.bitxor;
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

test "BITWISE 32 bit register and memory forms" {
    try validate(RegisterMemory_32, RegisterIndex_32, "AND EAX, ECX", &.{ 0x21, 0xC8 }, bitand.rm32_r32, .{ .reg = .EAX }, .ECX);
    try validate(RegisterMemory_32, RegisterIndex_32, "OR EAX, ECX", &.{ 0x09, 0xC8 }, bitor.rm32_r32, .{ .reg = .EAX }, .ECX);
    try validate(RegisterMemory_32, RegisterIndex_32, "XOR EAX, ECX", &.{ 0x31, 0xC8 }, bitxor.rm32_r32, .{ .reg = .EAX }, .ECX);

    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "AND R11D, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x23, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        bitand.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "OR R11D, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x0B, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        bitor.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "XOR R11D, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x33, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        bitxor.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
}

test "BITWISE 32 bit immediate forms" {
    try validate(
        RegisterMemory_32,
        u32,
        "AND [addr32:0x1234], 0x11223344",
        &.{ 0x67, 0x81, 0x24, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        bitand.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );
    try validate(
        RegisterMemory_32,
        u32,
        "OR [addr32:0x1234], 0x11223344",
        &.{ 0x67, 0x81, 0x0C, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        bitor.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );
    try validate(
        RegisterMemory_32,
        u32,
        "XOR [addr32:0x1234], 0x11223344",
        &.{ 0x67, 0x81, 0x34, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        bitxor.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );

    try validate(RegisterIndex_32, u32, "AND R11D, 0x01020304", &.{ 0x41, 0x81, 0xE3, 0x04, 0x03, 0x02, 0x01 }, bitand.r32_imm32, .R11D, 0x0102_0304);
    try validate(RegisterIndex_32, u32, "OR R11D, 0x01020304", &.{ 0x41, 0x81, 0xCB, 0x04, 0x03, 0x02, 0x01 }, bitor.r32_imm32, .R11D, 0x0102_0304);
    try validate(RegisterIndex_32, u32, "XOR R11D, 0x01020304", &.{ 0x41, 0x81, 0xF3, 0x04, 0x03, 0x02, 0x01 }, bitxor.r32_imm32, .R11D, 0x0102_0304);
}

test "BITWISE 32 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, bitxor.r32_rm32(&writer, .EAX, .{ .reg = .ECX }));
}
