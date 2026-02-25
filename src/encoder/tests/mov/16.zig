const std = @import("std");
const common = @import("common.zig");

const mov = common.mov;
const validate = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_16 = common.RegisterIndex_16;

test "MOV 16 bit registers" {
    // 66 89 c8                mov    ax,cx
    // 66 89 d3                mov    bx,dx
    // 66 89 fe                mov    si,di
    // 66 89 c7                mov    di,ax

    try validate(RegisterIndex_16, RegisterIndex_16, "AX, CX", &.{ 0x66, 0x89, 0xC8 }, mov.rm16_r16, .AX, .CX);
    try validate(RegisterIndex_16, RegisterIndex_16, "BX, DX", &.{ 0x66, 0x89, 0xD3 }, mov.rm16_r16, .BX, .DX);
    try validate(RegisterIndex_16, RegisterIndex_16, "SI, DI", &.{ 0x66, 0x89, 0xFE }, mov.rm16_r16, .SI, .DI);
    try validate(RegisterIndex_16, RegisterIndex_16, "DI, AX", &.{ 0x66, 0x89, 0xC7 }, mov.rm16_r16, .DI, .AX);
}

test "MOV 16 bit registers extended" {
    // 66 41 89 c0             mov    r8w,ax
    // 66 44 89 cb             mov    bx,r9w
    // 66 45 89 da             mov    r10w,r11w
    // 66 45 89 c7             mov    r15w,r8w

    try validate(RegisterIndex_16, RegisterIndex_16, "R8W, AX", &.{ 0x66, 0x41, 0x89, 0xC0 }, mov.rm16_r16, .R8W, .AX);
    try validate(RegisterIndex_16, RegisterIndex_16, "BX, R9W", &.{ 0x66, 0x44, 0x89, 0xCB }, mov.rm16_r16, .BX, .R9W);
    try validate(RegisterIndex_16, RegisterIndex_16, "R10W, R11W", &.{ 0x66, 0x45, 0x89, 0xDA }, mov.rm16_r16, .R10W, .R11W);
    try validate(RegisterIndex_16, RegisterIndex_16, "R15W, R8W", &.{ 0x66, 0x45, 0x89, 0xC7 }, mov.rm16_r16, .R15W, .R8W);
}

test "MOV 16 bit registers reverse encoding" {
    // 66 8b c1                mov    ax,cx
    // 66 44 8b c0             mov    r8w,ax
    try validate(RegisterIndex_16, RegisterIndex_16, "AX, CX", &.{ 0x66, 0x8B, 0xC1 }, mov.r16_rm16, .AX, .CX);
    try validate(RegisterIndex_16, RegisterIndex_16, "R8W, AX", &.{ 0x66, 0x44, 0x8B, 0xC0 }, mov.r16_rm16, .R8W, .AX);
}

test "MOV 16 bit immediate to r/m16 encoding" {
    // 66 c7 c0 34 12          mov    ax,0x1234
    // 66 41 c7 c1 78 56       mov    r9w,0x5678
    try validate(RegisterIndex_16, u16, "AX, 0x1234", &.{ 0x66, 0xC7, 0xC0, 0x34, 0x12 }, mov.rm16_imm16, .AX, 0x1234);
    try validate(RegisterIndex_16, u16, "R9W, 0x5678", &.{ 0x66, 0x41, 0xC7, 0xC1, 0x78, 0x56 }, mov.rm16_imm16, .R9W, 0x5678);
}

test "MOV 16 bit immediate to register" {
    // 66 b8 ff 00             mov    ax,0x00_ff
    // 66 b9 ff f0             mov    cx,0xf0_ff
    // 66 bf 34 12             mov    di,0x12_34
    // 66 bc ff ef             mov    sp,0xef_ff

    try validate(RegisterIndex_16, u16, "AX, 0xFF", &.{ 0x66, 0xB8, 0xFF, 0x00 }, mov.r16_imm16, .AX, 0xFF);
    try validate(RegisterIndex_16, u16, "CX, 0xF0_FF", &.{ 0x66, 0xB9, 0xFF, 0xF0 }, mov.r16_imm16, .CX, 0xF0FF);
    try validate(RegisterIndex_16, u16, "DI, 0x12_34", &.{ 0x66, 0xBF, 0x34, 0x12 }, mov.r16_imm16, .DI, 0x1234);
    try validate(RegisterIndex_16, u16, "SP, 0xEF_FF", &.{ 0x66, 0xBC, 0xFF, 0xEF }, mov.r16_imm16, .SP, 0xEFFF);
}

test "MOV 16 bit immediate to register extended" {
    // 66 41 b8 34 12          mov    r8w,0x12_34
    // 66 41 bf ff ef          mov    r15w,0xef_ff
    // 66 41 b9 00 00          mov    r9w,0x00_00
    // 66 41 bc 0f 0f          mov    r12w,0x0f_0f
    // 66 41 bd f0 f0          mov    r13w,0xf0_f0

    try validate(RegisterIndex_16, u16, "R8W, 0x12_34", &.{ 0x66, 0x41, 0xB8, 0x34, 0x12 }, mov.r16_imm16, .R8W, 0x1234);
    try validate(RegisterIndex_16, u16, "R15W, 0xEF_FF", &.{ 0x66, 0x41, 0xBF, 0xFF, 0xEF }, mov.r16_imm16, .R15W, 0xEFFF);
    try validate(RegisterIndex_16, u16, "R9W, 0x00_00", &.{ 0x66, 0x41, 0xB9, 0x00, 0x00 }, mov.r16_imm16, .R9W, 0x0000);
    try validate(RegisterIndex_16, u16, "R12W, 0x0F_0F", &.{ 0x66, 0x41, 0xBC, 0x0F, 0x0F }, mov.r16_imm16, .R12W, 0x0F0F);
    try validate(RegisterIndex_16, u16, "R13W, 0xF0_F0", &.{ 0x66, 0x41, 0xBD, 0xF0, 0xF0 }, mov.r16_imm16, .R13W, 0xF0F0);
}

test "MOV 16 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, mov.rm16_r16(&writer, .AX, .CX));
    try std.testing.expectError(EncodingError.WriterError, mov.r16_rm16(&writer, .AX, .CX));
    try std.testing.expectError(EncodingError.WriterError, mov.rm16_imm16(&writer, .AX, 0x1234));
    try std.testing.expectError(EncodingError.WriterError, mov.r16_imm16(&writer, .AX, 0x1234));
}
