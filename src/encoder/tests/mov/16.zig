const std = @import("std");
const common = @import("common.zig");

const mov = common.mov;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_16 = common.RegisterIndex_16;
const RegisterMemory_16 = common.RegisterMemory_16;

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

test "MOV 16 bit registers" {
    try validate(RegisterMemory_16, RegisterIndex_16, "AX, CX", &.{ 0x66, 0x89, 0xC8 }, mov.rm16_r16, .{ .reg = .AX }, .CX);
    try validate(RegisterMemory_16, RegisterIndex_16, "BX, DX", &.{ 0x66, 0x89, 0xD3 }, mov.rm16_r16, .{ .reg = .BX }, .DX);
    try validate(RegisterMemory_16, RegisterIndex_16, "SI, DI", &.{ 0x66, 0x89, 0xFE }, mov.rm16_r16, .{ .reg = .SI }, .DI);
    try validate(RegisterMemory_16, RegisterIndex_16, "DI, AX", &.{ 0x66, 0x89, 0xC7 }, mov.rm16_r16, .{ .reg = .DI }, .AX);
}

test "MOV 16 bit registers extended" {
    try validate(RegisterMemory_16, RegisterIndex_16, "R8W, AX", &.{ 0x66, 0x41, 0x89, 0xC0 }, mov.rm16_r16, .{ .reg = .R8W }, .AX);
    try validate(RegisterMemory_16, RegisterIndex_16, "BX, R9W", &.{ 0x66, 0x44, 0x89, 0xCB }, mov.rm16_r16, .{ .reg = .BX }, .R9W);
    try validate(RegisterMemory_16, RegisterIndex_16, "R10W, R11W", &.{ 0x66, 0x45, 0x89, 0xDA }, mov.rm16_r16, .{ .reg = .R10W }, .R11W);
    try validate(RegisterMemory_16, RegisterIndex_16, "R15W, R8W", &.{ 0x66, 0x45, 0x89, 0xC7 }, mov.rm16_r16, .{ .reg = .R15W }, .R8W);
}

test "MOV 16 bit registers reverse encoding" {
    try validate(RegisterIndex_16, RegisterMemory_16, "AX, CX", &.{ 0x66, 0x8B, 0xC1 }, mov.r16_rm16, .AX, .{ .reg = .CX });
    try validate(RegisterIndex_16, RegisterMemory_16, "R8W, AX", &.{ 0x66, 0x44, 0x8B, 0xC0 }, mov.r16_rm16, .R8W, .{ .reg = .AX });
    try validate(RegisterIndex_16, RegisterMemory_16, "BX, R9W", &.{ 0x66, 0x41, 0x8B, 0xD9 }, mov.r16_rm16, .BX, .{ .reg = .R9W });
    try validate(RegisterIndex_16, RegisterMemory_16, "DI, R13W", &.{ 0x66, 0x41, 0x8B, 0xFD }, mov.r16_rm16, .DI, .{ .reg = .R13W });
}

test "MOV 16 bit immediate to r/m16 encoding" {
    try validate(RegisterMemory_16, u16, "AX, 0x1234", &.{ 0x66, 0xC7, 0xC0, 0x34, 0x12 }, mov.rm16_imm16, .{ .reg = .AX }, 0x1234);
    try validate(RegisterMemory_16, u16, "R9W, 0x5678", &.{ 0x66, 0x41, 0xC7, 0xC1, 0x78, 0x56 }, mov.rm16_imm16, .{ .reg = .R9W }, 0x5678);
    try validate(RegisterMemory_16, u16, "DI, 0xBEEF", &.{ 0x66, 0xC7, 0xC7, 0xEF, 0xBE }, mov.rm16_imm16, .{ .reg = .DI }, 0xBEEF);
}

test "MOV 16 bit immediate to register" {
    try validate(RegisterIndex_16, u16, "AX, 0xFF", &.{ 0x66, 0xB8, 0xFF, 0x00 }, mov.r16_imm16, .AX, 0xFF);
    try validate(RegisterIndex_16, u16, "CX, 0xF0_FF", &.{ 0x66, 0xB9, 0xFF, 0xF0 }, mov.r16_imm16, .CX, 0xF0FF);
    try validate(RegisterIndex_16, u16, "DI, 0x12_34", &.{ 0x66, 0xBF, 0x34, 0x12 }, mov.r16_imm16, .DI, 0x1234);
    try validate(RegisterIndex_16, u16, "SP, 0xEF_FF", &.{ 0x66, 0xBC, 0xFF, 0xEF }, mov.r16_imm16, .SP, 0xEFFF);
}

test "MOV 16 bit immediate to register extended" {
    try validate(RegisterIndex_16, u16, "R8W, 0x12_34", &.{ 0x66, 0x41, 0xB8, 0x34, 0x12 }, mov.r16_imm16, .R8W, 0x1234);
    try validate(RegisterIndex_16, u16, "R15W, 0xEF_FF", &.{ 0x66, 0x41, 0xBF, 0xFF, 0xEF }, mov.r16_imm16, .R15W, 0xEFFF);
    try validate(RegisterIndex_16, u16, "R9W, 0x00_00", &.{ 0x66, 0x41, 0xB9, 0x00, 0x00 }, mov.r16_imm16, .R9W, 0x0000);
    try validate(RegisterIndex_16, u16, "R12W, 0x0F_0F", &.{ 0x66, 0x41, 0xBC, 0x0F, 0x0F }, mov.r16_imm16, .R12W, 0x0F0F);
    try validate(RegisterIndex_16, u16, "R13W, 0xF0_F0", &.{ 0x66, 0x41, 0xBD, 0xF0, 0xF0 }, mov.r16_imm16, .R13W, 0xF0F0);
}

test "MOV 16 bit RIP-relative memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[RIP + 0x1234], AX",
        &.{ 0x66, 0x89, 0x05, 0x34, 0x12, 0x00, 0x00 },
        mov.rm16_r16,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R9W, [RIP - 8]",
        &.{ 0x66, 0x44, 0x8B, 0x0D, 0xF8, 0xFF, 0xFF, 0xFF },
        mov.r16_rm16,
        .R9W,
        .{ .mem = .{ .ripRelative = -8 } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[RIP + 0x10], 0xBEEF",
        &.{ 0x66, 0xC7, 0x05, 0x10, 0x00, 0x00, 0x00, 0xEF, 0xBE },
        mov.rm16_imm16,
        .{ .mem = .{ .ripRelative = 0x10 } },
        0xBEEF,
    );
}

test "MOV 16 bit base-index64 memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[R8], AX",
        &.{ 0x66, 0x41, 0x89, 0x00 },
        mov.rm16_r16,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .AX,
    );
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[R9 + 4], AX",
        &.{ 0x66, 0x41, 0x89, 0x41, 0x04 },
        mov.rm16_r16,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .AX,
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[RAX + R10*2 - 4], 0x1234",
        &.{ 0x66, 0x42, 0xC7, 0x44, 0x50, 0xFC, 0x34, 0x12 },
        mov.rm16_imm16,
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
        0x1234,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [R8]",
        &.{ 0x66, 0x45, 0x8B, 0x18 },
        mov.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [R9 + 4]",
        &.{ 0x66, 0x45, 0x8B, 0x59, 0x04 },
        mov.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[RAX + R10*8 + 0x10], R11W",
        &.{ 0x66, 0x46, 0x89, 0x5C, 0xD0, 0x10 },
        mov.rm16_r16,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{
                        .reg = .R10,
                        .scale = .x8,
                    },
                    .disp = 0x10,
                },
            },
        },
        .R11W,
    );
}

test "MOV 16 bit base-index32 memory" {
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[EBX + ECX*2], AX",
        &.{ 0x66, 0x67, 0x89, 0x04, 0x4B },
        mov.rm16_r16,
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
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [EBX + ECX*2]",
        &.{ 0x66, 0x67, 0x44, 0x8B, 0x1C, 0x4B },
        mov.r16_rm16,
        .R11W,
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
    );
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[R8D], AX",
        &.{ 0x66, 0x67, 0x41, 0x89, 0x00 },
        mov.rm16_r16,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [R8D]",
        &.{ 0x66, 0x67, 0x45, 0x8B, 0x18 },
        mov.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[EBP], 0x1234",
        &.{ 0x66, 0x67, 0xC7, 0x45, 0x00, 0x34, 0x12 },
        mov.rm16_imm16,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x1234,
    );
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[ECX*4 + 0x1234], AX",
        &.{ 0x66, 0x67, 0x89, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        mov.rm16_r16,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = null,
                    .index = .{
                        .reg = .ECX,
                        .scale = .x4,
                    },
                    .disp = 0x1234,
                },
            },
        },
        .AX,
    );
    try validate(
        RegisterMemory_16,
        RegisterIndex_16,
        "[addr32:0x1234], AX",
        &.{ 0x66, 0x67, 0x89, 0x05, 0x34, 0x12, 0x00, 0x00 },
        mov.rm16_r16,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        .AX,
    );
    try validate(
        RegisterIndex_16,
        RegisterMemory_16,
        "R11W, [addr32:0x1234]",
        &.{ 0x66, 0x67, 0x44, 0x8B, 0x1D, 0x34, 0x12, 0x00, 0x00 },
        mov.r16_rm16,
        .R11W,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_16,
        u16,
        "[addr32:0x1234], 0x1234",
        &.{ 0x66, 0x67, 0xC7, 0x05, 0x34, 0x12, 0x00, 0x00, 0x34, 0x12 },
        mov.rm16_imm16,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1234,
    );
}

test "MOV 16 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(
        EncodingError.WriterError,
        mov.rm16_r16(&writer, .{ .reg = .AX }, .CX),
    );
    try std.testing.expectError(
        EncodingError.WriterError,
        mov.r16_rm16(&writer, .AX, .{ .reg = .CX }),
    );
    try std.testing.expectError(
        EncodingError.WriterError,
        mov.rm16_imm16(&writer, .{ .reg = .AX }, 0x1234),
    );
    try std.testing.expectError(
        EncodingError.WriterError,
        mov.r16_imm16(&writer, .AX, 0x1234),
    );
}
