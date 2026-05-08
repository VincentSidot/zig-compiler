const std = @import("std");
const common = @import("common.zig");

const push = common.push;
const validate_impl = common.validate;
const validate_imm8_impl = common.validate_imm8;
const validate_imm16_impl = common.validate_imm16;
const validate_imm32_impl = common.validate_imm32;
const EncodingError = common.EncodingError;
const RegisterIndex_16 = common.RegisterIndex_16;
const RegisterIndex_32 = common.RegisterIndex_32;
const RegisterIndex_64 = common.RegisterIndex_64;
const RegisterMemory_16 = common.RegisterMemory_16;
const RegisterMemory_32 = common.RegisterMemory_32;
const RegisterMemory_64 = common.RegisterMemory_64;

fn validate(
    comptime Dest: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn (writer: *std.Io.Writer, dest: Dest) EncodingError!usize,
    dest: Dest,
) !void {
    try validate_impl(Dest, name, expected, tested, dest);
}

fn validate_imm8(
    comptime name: []const u8,
    comptime expected: []const u8,
    value: i8,
) !void {
    try validate_imm8_impl(name, expected, value);
}

fn validate_imm32(
    comptime name: []const u8,
    comptime expected: []const u8,
    value: u32,
) !void {
    try validate_imm32_impl(name, expected, value);
}

fn validate_imm16(
    comptime name: []const u8,
    comptime expected: []const u8,
    value: u16,
) !void {
    try validate_imm16_impl(name, expected, value);
}

test "PUSH r64 forms" {
    try validate(RegisterIndex_64, "RAX", &.{0x50}, push.r64, .RAX);
    try validate(RegisterIndex_64, "RCX", &.{0x51}, push.r64, .RCX);
    try validate(RegisterIndex_64, "R9", &.{ 0x41, 0x51 }, push.r64, .R9);
    try validate(RegisterIndex_64, "R15", &.{ 0x41, 0x57 }, push.r64, .R15);
}

test "PUSH r16 forms" {
    try validate(RegisterIndex_16, "AX", &.{ 0x66, 0x50 }, push.r16, .AX);
    try validate(RegisterIndex_16, "CX", &.{ 0x66, 0x51 }, push.r16, .CX);
    try validate(RegisterIndex_16, "R9W", &.{ 0x66, 0x41, 0x51 }, push.r16, .R9W);
    try validate(RegisterIndex_16, "R15W", &.{ 0x66, 0x41, 0x57 }, push.r16, .R15W);
}

test "PUSH r32 forms" {
    try validate(RegisterIndex_32, "EAX", &.{0x50}, push.r32, .EAX);
    try validate(RegisterIndex_32, "ECX", &.{0x51}, push.r32, .ECX);
    try validate(RegisterIndex_32, "R9D", &.{ 0x41, 0x51 }, push.r32, .R9D);
    try validate(RegisterIndex_32, "R15D", &.{ 0x41, 0x57 }, push.r32, .R15D);
}

test "PUSH imm forms" {
    try validate_imm8("imm8 -1", &.{ 0x6A, 0xFF }, -1);
    try validate_imm8("imm8 +0x7f", &.{ 0x6A, 0x7F }, 0x7F);
    try validate_imm16("imm16 0x1234", &.{ 0x66, 0x68, 0x34, 0x12 }, 0x1234);

    try validate_imm32("imm32 0x11223344", &.{ 0x68, 0x44, 0x33, 0x22, 0x11 }, 0x1122_3344);
}

test "PUSH rm register forms" {
    try validate(RegisterMemory_16, "AX", &.{ 0x66, 0xFF, 0xF0 }, push.rm16, .{ .reg = .AX });
    try validate(RegisterMemory_16, "R9W", &.{ 0x66, 0x41, 0xFF, 0xF1 }, push.rm16, .{ .reg = .R9W });

    try validate(RegisterMemory_32, "EAX", &.{ 0xFF, 0xF0 }, push.rm32, .{ .reg = .EAX });
    try validate(RegisterMemory_32, "R9D", &.{ 0x41, 0xFF, 0xF1 }, push.rm32, .{ .reg = .R9D });

    try validate(RegisterMemory_64, "RAX", &.{ 0xFF, 0xF0 }, push.rm64, .{ .reg = .RAX });
    try validate(RegisterMemory_64, "R9", &.{ 0x41, 0xFF, 0xF1 }, push.rm64, .{ .reg = .R9 });
}

test "PUSH rm64 memory forms" {
    try validate(RegisterMemory_64, "[RAX]", &.{ 0xFF, 0x30 }, push.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_64, "[RAX + 0x20]", &.{ 0xFF, 0x70, 0x20 }, push.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = 0x20 } } });
    try validate(RegisterMemory_64, "[R12]", &.{ 0x41, 0xFF, 0x34, 0x24 }, push.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .R12 } } });
    try validate(RegisterMemory_64, "[R13]", &.{ 0x41, 0xFF, 0x75, 0x00 }, push.rm64, .{ .mem = .{ .baseIndex64 = .{ .base = .R13 } } });
    try validate(RegisterMemory_64, "[RIP + 0x20]", &.{ 0xFF, 0x35, 0x20, 0x00, 0x00, 0x00 }, push.rm64, .{ .mem = .{ .ripRelative = 0x20 } });
    try validate(RegisterMemory_64, "[RCX*4 + 0x1234]", &.{ 0xFF, 0x34, 0x8D, 0x34, 0x12, 0x00, 0x00 }, push.rm64, .{
        .mem = .{
            .baseIndex64 = .{
                .base = null,
                .index = .{ .reg = .RCX, .scale = .x4 },
                .disp = 0x1234,
            },
        },
    });
}

test "PUSH rm16 memory forms" {
    try validate(RegisterMemory_16, "[RAX]", &.{ 0x66, 0xFF, 0x30 }, push.rm16, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_16, "[R9]", &.{ 0x66, 0x41, 0xFF, 0x31 }, push.rm16, .{ .mem = .{ .baseIndex64 = .{ .base = .R9 } } });
    try validate(RegisterMemory_16, "[addr32:0x1234]", &.{ 0x66, 0x67, 0xFF, 0x34, 0x25, 0x34, 0x12, 0x00, 0x00 }, push.rm16, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });
}

test "PUSH rm32 memory forms" {
    try validate(RegisterMemory_32, "[RAX]", &.{ 0xFF, 0x30 }, push.rm32, .{ .mem = .{ .baseIndex64 = .{ .base = .RAX } } });
    try validate(RegisterMemory_32, "[R9]", &.{ 0x41, 0xFF, 0x31 }, push.rm32, .{ .mem = .{ .baseIndex64 = .{ .base = .R9 } } });
    try validate(RegisterMemory_32, "[addr32:0x1234]", &.{ 0x67, 0xFF, 0x34, 0x25, 0x34, 0x12, 0x00, 0x00 }, push.rm32, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });
}

test "PUSH address-size override forms" {
    try validate(RegisterMemory_64, "[R8D]", &.{ 0x67, 0x41, 0xFF, 0x30 }, push.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } });
    try validate(RegisterMemory_64, "[EBP]", &.{ 0x67, 0xFF, 0x75, 0x00 }, push.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } });
    try validate(RegisterMemory_64, "[addr32:0x1234]", &.{ 0x67, 0xFF, 0x34, 0x25, 0x34, 0x12, 0x00, 0x00 }, push.rm64, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });
}

test "PUSH writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    try std.testing.expectError(EncodingError.WriterError, push.r64(&writer, .RAX));
    try std.testing.expectError(EncodingError.WriterError, push.r16(&writer, .AX));
    try std.testing.expectError(EncodingError.WriterError, push.rm16(&writer, .{ .reg = .AX }));
    try std.testing.expectError(EncodingError.WriterError, push.imm8(&writer, -1));
    try std.testing.expectError(EncodingError.WriterError, push.imm16(&writer, 0x1234));
}
