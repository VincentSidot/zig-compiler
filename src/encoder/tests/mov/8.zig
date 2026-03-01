const std = @import("std");
const common = @import("common.zig");

const mov = common.mov;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_8 = common.RegisterIndex_8;
const RegisterMemory_8 = common.RegisterMemory_8;

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

test "MOV 8 bit registers" {
    // 88 c8                   mov    al,cl
    // 88 d1                   mov    cl,dl
    // 88 da                   mov    dl,bl
    // 88 c3                   mov    bl,al
    // 88 d4                   mov    ah,dl
    // 88 fb                   mov    bl,bh
    // 88 ea                   mov    dl,ch
    // 88 e6                   mov    dh,ah

    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "AL, CL",
        &.{ 0x88, 0xC8 },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .AL },
        .CL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "CL, DL",
        &.{ 0x88, 0xD1 },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .CL },
        .DL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "DL, BL",
        &.{ 0x88, 0xDA },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .DL },
        .BL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "BL, AL",
        &.{ 0x88, 0xC3 },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .BL },
        .AL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "AH, DL",
        &.{ 0x88, 0xD4 },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .AH },
        .DL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "BL, BH",
        &.{ 0x88, 0xFB },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .BL },
        .BH,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "DL, CH",
        &.{ 0x88, 0xEA },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .DL },
        .CH,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "DH, AH",
        &.{ 0x88, 0xE6 },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .DH },
        .AH,
    );
}

test "MOV 8 bit registers extended" {
    // 40 88 ec                mov    spl,bpl
    // 40 88 f7                mov    dil,sil
    // 41 88 c0                mov    r8b,al
    // 44 88 cb                mov    bl,r9b
    // 45 88 da                mov    r10b,r11b
    // 45 88 c7                mov    r15b,r8b

    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "SPL, BPL",
        &.{ 0x40, 0x88, 0xEC },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .SPL },
        .BPL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "DIL, SIL",
        &.{ 0x40, 0x88, 0xF7 },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .DIL },
        .SIL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "R8B, AL",
        &.{ 0x41, 0x88, 0xC0 },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .R8B },
        .AL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "BL, R9B",
        &.{ 0x44, 0x88, 0xCB },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .BL },
        .R9B,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "R10B, R11B",
        &.{ 0x45, 0x88, 0xDA },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .R10B },
        .R11B,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "R15B, R8B",
        &.{ 0x45, 0x88, 0xC7 },
        mov.rm8_r8,
        RegisterMemory_8{ .reg = .R15B },
        .R8B,
    );
}

test "MOV 8 bit registers reverse encoding" {
    // 8a c1                   mov    al,cl
    // 41 8a c0                mov    al,r8b
    // 44 8a cb                mov    r9b,bl
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "AL, CL",
        &.{ 0x8A, 0xC1 },
        mov.r8_rm8,
        .AL,
        RegisterMemory_8{ .reg = .CL },
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "AL, R8B",
        &.{ 0x41, 0x8A, 0xC0 },
        mov.r8_rm8,
        .AL,
        RegisterMemory_8{ .reg = .R8B },
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R9B, BL",
        &.{ 0x44, 0x8A, 0xCB },
        mov.r8_rm8,
        .R9B,
        RegisterMemory_8{ .reg = .BL },
    );
}

test "MOV 8 bit invalid combinations" {
    // High byte registers cannot be used with REX prefix
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    try std.testing.expectError(
        EncodingError.InvalidOperand,
        mov.rm8_r8(&writer, RegisterMemory_8{ .reg = .AH }, .SPL),
    );
    try std.testing.expectError(
        EncodingError.InvalidOperand,
        mov.rm8_r8(&writer, RegisterMemory_8{ .reg = .SPL }, .AH),
    );
    try std.testing.expectError(
        EncodingError.InvalidOperand,
        mov.rm8_r8(&writer, RegisterMemory_8{ .reg = .BH }, .R8B),
    );
    try std.testing.expectError(
        EncodingError.InvalidOperand,
        mov.rm8_r8(&writer, RegisterMemory_8{ .reg = .R8B }, .BH),
    );

    // Same invalid matrix for reverse encoding path (r8, r/m8).
    try std.testing.expectError(
        EncodingError.InvalidOperand,
        mov.r8_rm8(&writer, .AH, RegisterMemory_8{ .reg = .SPL }),
    );
    try std.testing.expectError(
        EncodingError.InvalidOperand,
        mov.r8_rm8(&writer, .SPL, RegisterMemory_8{ .reg = .AH }),
    );
    try std.testing.expectError(
        EncodingError.InvalidOperand,
        mov.r8_rm8(&writer, .BH, RegisterMemory_8{ .reg = .R8B }),
    );
    try std.testing.expectError(
        EncodingError.InvalidOperand,
        mov.r8_rm8(&writer, .R8B, RegisterMemory_8{ .reg = .BH }),
    );
}

test "MOV 8 bit immediate to register" {
    // b0 ff                   mov    al,0xff
    // b3 ff                   mov    bl,0xff
    // b1 ff                   mov    cl,0xff
    // b4 ff                   mov    ah,0xff

    try validate(
        RegisterIndex_8,
        u8,
        "AL, 0xFF",
        &.{ 0xB0, 0xFF },
        mov.r8_imm8,
        .AL,
        0xFF,
    );
    try validate(
        RegisterIndex_8,
        u8,
        "BL, 0xFF",
        &.{ 0xB3, 0xFF },
        mov.r8_imm8,
        .BL,
        0xFF,
    );
    try validate(
        RegisterIndex_8,
        u8,
        "CL, 0xFF",
        &.{ 0xB1, 0xFF },
        mov.r8_imm8,
        .CL,
        0xFF,
    );
    try validate(
        RegisterIndex_8,
        u8,
        "AH, 0xFF",
        &.{ 0xB4, 0xFF },
        mov.r8_imm8,
        .AH,
        0xFF,
    );
}

test "MOV 8 bit immediate to register extended" {
    // 41 b0 ff                mov    r8b,0xff
    // 41 b7 0a                mov    r15b,0xa
    // 41 b1 00                mov    r9b,0x0
    // 41 b4 af                mov    r12b,0xaf
    // 41 c6 c0 42             mov    r8b,0x42

    try validate(
        RegisterIndex_8,
        u8,
        "R8B, 0xFF",
        &.{ 0x41, 0xB0, 0xFF },
        mov.r8_imm8,
        .R8B,
        0xFF,
    );
    try validate(
        RegisterIndex_8,
        u8,
        "R15B, 0x0A",
        &.{ 0x41, 0xB7, 0x0A },
        mov.r8_imm8,
        .R15B,
        0x0A,
    );
    try validate(
        RegisterIndex_8,
        u8,
        "R9B, 0x00",
        &.{ 0x41, 0xB1, 0x00 },
        mov.r8_imm8,
        .R9B,
        0x00,
    );
    try validate(
        RegisterIndex_8,
        u8,
        "R12B, 0xAF",
        &.{ 0x41, 0xB4, 0xAF },
        mov.r8_imm8,
        .R12B,
        0xAF,
    );
    try validate(
        RegisterMemory_8,
        u8,
        "R8B, 0x42 // Using MOV r/m8, imm8 encoding",
        &.{ 0x41, 0xC6, 0xC0, 0x42 },
        mov.rm8_imm8,
        RegisterMemory_8{ .reg = .R8B },
        0x42,
    );
}

test "MOV 8 bit immediate low and high-byte edge cases" {
    // 40 b4 11                mov    spl,0x11
    // 40 b5 22                mov    bpl,0x22
    // 40 b6 33                mov    sil,0x33
    // 40 b7 44                mov    dil,0x44
    // c6 c4 55                mov    ah,0x55
    try validate(
        RegisterIndex_8,
        u8,
        "SPL, 0x11",
        &.{ 0x40, 0xB4, 0x11 },
        mov.r8_imm8,
        .SPL,
        0x11,
    );
    try validate(
        RegisterIndex_8,
        u8,
        "BPL, 0x22",
        &.{ 0x40, 0xB5, 0x22 },
        mov.r8_imm8,
        .BPL,
        0x22,
    );
    try validate(
        RegisterIndex_8,
        u8,
        "SIL, 0x33",
        &.{ 0x40, 0xB6, 0x33 },
        mov.r8_imm8,
        .SIL,
        0x33,
    );
    try validate(
        RegisterIndex_8,
        u8,
        "DIL, 0x44",
        &.{ 0x40, 0xB7, 0x44 },
        mov.r8_imm8,
        .DIL,
        0x44,
    );
    try validate(
        RegisterMemory_8,
        u8,
        "AH, 0x55",
        &.{ 0xC6, 0xC4, 0x55 },
        mov.rm8_imm8,
        RegisterMemory_8{ .reg = .AH },
        0x55,
    );
}

test "MOV 8 bit RIP-relative memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[RIP + 0x12345678], AL",
        &.{ 0x88, 0x05, 0x78, 0x56, 0x34, 0x12 },
        mov.rm8_r8,
        .{ .mem = .{ .ripRelative = 0x1234_5678 } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "CL, [RIP - 4]",
        &.{ 0x8A, 0x0D, 0xFC, 0xFF, 0xFF, 0xFF },
        mov.r8_rm8,
        .CL,
        .{ .mem = .{ .ripRelative = -4 } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[RIP + 0x20], 0x7F",
        &.{ 0xC6, 0x05, 0x20, 0x00, 0x00, 0x00, 0x7F },
        mov.rm8_imm8,
        .{ .mem = .{ .ripRelative = 0x20 } },
        0x7F,
    );
}

test "MOV 8 bit base-index64 memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[R8], AL",
        &.{ 0x41, 0x88, 0x00 },
        mov.rm8_r8,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .AL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[R9 + 4], AL",
        &.{ 0x41, 0x88, 0x41, 0x04 },
        mov.rm8_r8,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .AL,
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[RAX + R10*2 - 4], 0x42",
        &.{ 0x42, 0xC6, 0x44, 0x50, 0xFC, 0x42 },
        mov.rm8_imm8,
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
        0x42,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [R8]",
        &.{ 0x45, 0x8A, 0x18 },
        mov.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [R9 + 4]",
        &.{ 0x45, 0x8A, 0x59, 0x04 },
        mov.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[RAX + R10*8 + 0x10], R11B",
        &.{ 0x46, 0x88, 0x5C, 0xD0, 0x10 },
        mov.rm8_r8,
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
        .R11B,
    );
}

test "MOV 8 bit base-index32 memory" {
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[EBX + ECX*2], AL",
        &.{ 0x67, 0x88, 0x04, 0x4B },
        mov.rm8_r8,
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
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [EBX + ECX*2]",
        &.{ 0x67, 0x44, 0x8A, 0x1C, 0x4B },
        mov.r8_rm8,
        .R11B,
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
        RegisterMemory_8,
        RegisterIndex_8,
        "[R8D], AL",
        &.{ 0x67, 0x41, 0x88, 0x00 },
        mov.rm8_r8,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [R8D]",
        &.{ 0x67, 0x45, 0x8A, 0x18 },
        mov.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[EBP], 0x44",
        &.{ 0x67, 0xC6, 0x45, 0x00, 0x44 },
        mov.rm8_imm8,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x44,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[ECX*4 + 0x1234], AL",
        &.{ 0x67, 0x88, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        mov.rm8_r8,
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
        .AL,
    );
    try validate(
        RegisterMemory_8,
        RegisterIndex_8,
        "[addr32:0x1234], AL",
        &.{ 0x67, 0x88, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        mov.rm8_r8,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        .AL,
    );
    try validate(
        RegisterIndex_8,
        RegisterMemory_8,
        "R11B, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x8A, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        mov.r8_rm8,
        .R11B,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_8,
        u8,
        "[addr32:0x1234], 0x44",
        &.{ 0x67, 0xC6, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44 },
        mov.rm8_imm8,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x44,
    );
}

test "MOV 8 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(
        EncodingError.WriterError,
        mov.rm8_r8(&writer, RegisterMemory_8{ .reg = .AL }, .CL),
    );
    try std.testing.expectError(
        EncodingError.WriterError,
        mov.r8_rm8(&writer, .AL, RegisterMemory_8{ .reg = .CL }),
    );
    try std.testing.expectError(
        EncodingError.WriterError,
        mov.rm8_imm8(&writer, RegisterMemory_8{ .reg = .AL }, 0x11),
    );
    try std.testing.expectError(
        EncodingError.WriterError,
        mov.r8_imm8(&writer, .AL, 0x11),
    );
}
