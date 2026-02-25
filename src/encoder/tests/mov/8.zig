const std = @import("std");
const common = @import("common.zig");

const mov = common.mov;
const validate = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_8 = common.RegisterIndex_8;
const RegisterMemory_8 = common.RegisterMemory_8;

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
