const std = @import("std");
const common = @import("common.zig");

const sub = common.sub;
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
    tested: fn (writer: *std.Io.Writer, dest: Dest, source: Src) EncodingError!usize,
    dest: Dest,
    source: Src,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_impl(Dest, Src, name, expected, tested, dest, source);
}

test "SUB 32 bit register and immediate forms" {
    try validate(RegisterMemory_32, RegisterIndex_32, "EAX, ECX", &.{ 0x29, 0xC8 }, sub.rm32_r32, .{ .reg = .EAX }, .ECX);
    try validate(RegisterIndex_32, RegisterMemory_32, "R11D, [addr32:0x1234]", &.{ 0x67, 0x44, 0x2B, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 }, sub.r32_rm32, .R11D, .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } });

    try validate(RegisterMemory_32, u32, "[EBP], 0x11223344", &.{ 0x67, 0x81, 0x6D, 0x00, 0x44, 0x33, 0x22, 0x11 }, sub.rm32_imm32, .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } }, 0x1122_3344);
    try validate(RegisterIndex_32, u32, "R11D, 0x01020304", &.{ 0x41, 0x81, 0xEB, 0x04, 0x03, 0x02, 0x01 }, sub.r32_imm32, .R11D, 0x0102_0304);
}

test "SUB 32 bit RIP-relative memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[RIP + 0x1234], ECX",
        &.{ 0x29, 0x0D, 0x34, 0x12, 0x00, 0x00 },
        sub.rm32_r32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .ECX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R9D, [RIP - 16]",
        &.{ 0x44, 0x2B, 0x0D, 0xF0, 0xFF, 0xFF, 0xFF },
        sub.r32_rm32,
        .R9D,
        .{ .mem = .{ .ripRelative = -16 } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[RIP + 0x1234], 0x89AB_CDEF",
        &.{ 0x81, 0x2D, 0x34, 0x12, 0x00, 0x00, 0xEF, 0xCD, 0xAB, 0x89 },
        sub.rm32_imm32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        0x89AB_CDEF,
    );
}

test "SUB 32 bit base-index64 memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[R8], EAX",
        &.{ 0x41, 0x29, 0x00 },
        sub.rm32_r32,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .EAX,
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[R9 + 4], EAX",
        &.{ 0x41, 0x29, 0x41, 0x04 },
        sub.rm32_r32,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .EAX,
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[RAX + R10*2 - 4], 0x11223344",
        &.{ 0x42, 0x81, 0x6C, 0x50, 0xFC, 0x44, 0x33, 0x22, 0x11 },
        sub.rm32_imm32,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{
                        .reg = .R10,
                        .scale = .x2,
                    },
                    .disp = -4,
                },
            },
        },
        0x1122_3344,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [R8]",
        &.{ 0x45, 0x2B, 0x18 },
        sub.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
}

test "SUB 32 bit base-index32 memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[EBX + ECX*2], EAX",
        &.{ 0x67, 0x29, 0x04, 0x4B },
        sub.rm32_r32,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = .EBX,
                    .index = .{
                        .reg = .ECX,
                        .scale = .x2,
                    },
                },
            },
        },
        .EAX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [R8D]",
        &.{ 0x67, 0x45, 0x2B, 0x18 },
        sub.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[addr32:0x1234], 0x11223344",
        &.{ 0x67, 0x81, 0x2C, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        sub.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );
}

test "SUB 32 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, sub.r32_rm32(&writer, .EAX, .{ .reg = .ECX }));
}
