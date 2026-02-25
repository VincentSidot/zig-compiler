const std = @import("std");

const helper = @import("../../helper.zig");
const eprintf = helper.eprintf;

const lib_file = @import("../lib.zig");
const mov_file = @import("../mov.zig");

const mov = mov_file.mov;
const OPCodeOutput = mov_file.OPCodeOutput;

const EncodingError = lib_file.EncodingError;

pub const RegisterIndex_64 = lib_file.RegisterIndex_64;
pub const RegisterIndex_32 = lib_file.RegisterIndex_32;
pub const RegisterIndex_16 = lib_file.RegisterIndex_16;
pub const RegisterIndex_8 = lib_file.RegisterIndex_8;

fn print_buffer(comptime prefix: []const u8, buff: []const u8) void {
    eprintf(prefix ++ ": ", .{});
    for (buff) |byte| {
        eprintf("{x:02} ", .{byte});
    }
    eprintf("\n", .{});
}

fn fn_mov(comptime D: type, comptime S: type) type {
    return fn (writer: *std.io.Writer, dest: D, source: S) EncodingError!usize;
}

fn validate(
    comptime D: type,
    comptime S: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn_mov(D, S),
    dest: D,
    source: S,
) !void {
    eprintf("Validating MOV \"{s}\" instruction: ", .{name});

    var buffer: [16]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    const writen = try tested(&writer, dest, source);

    print_buffer("", buffer[0..writen]);

    if (writen != expected.len) {
        eprintf("Expected {d} bytes but got {d}\n", .{ expected.len, writen });
        return error.InvalidEncodingLength;
    }

    if (!std.mem.eql(u8, buffer[0..writen], expected)) {
        print_buffer("Expected", expected);
        return error.InvalidEncodingData;
    }
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
        RegisterIndex_8,
        RegisterIndex_8,
        "AL, CL",
        &.{ 0x88, 0xC8 },
        mov.rm8_r8,
        .AL,
        .CL,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "CL, DL",
        &.{ 0x88, 0xD1 },
        mov.rm8_r8,
        .CL,
        .DL,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "DL, BL",
        &.{ 0x88, 0xDA },
        mov.rm8_r8,
        .DL,
        .BL,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "BL, AL",
        &.{ 0x88, 0xC3 },
        mov.rm8_r8,
        .BL,
        .AL,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "AH, DL",
        &.{ 0x88, 0xD4 },
        mov.rm8_r8,
        .AH,
        .DL,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "BL, BH",
        &.{ 0x88, 0xFB },
        mov.rm8_r8,
        .BL,
        .BH,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "DL, CH",
        &.{ 0x88, 0xEA },
        mov.rm8_r8,
        .DL,
        .CH,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "DH, AH",
        &.{ 0x88, 0xE6 },
        mov.rm8_r8,
        .DH,
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
        RegisterIndex_8,
        RegisterIndex_8,
        "SPL, BPL",
        &.{ 0x40, 0x88, 0xEC },
        mov.rm8_r8,
        .SPL,
        .BPL,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "DIL, SIL",
        &.{ 0x40, 0x88, 0xF7 },
        mov.rm8_r8,
        .DIL,
        .SIL,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "R8B, AL",
        &.{ 0x41, 0x88, 0xC0 },
        mov.rm8_r8,
        .R8B,
        .AL,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "BL, R9B",
        &.{ 0x44, 0x88, 0xCB },
        mov.rm8_r8,
        .BL,
        .R9B,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "R10B, R11B",
        &.{ 0x45, 0x88, 0xDA },
        mov.rm8_r8,
        .R10B,
        .R11B,
    );

    try validate(
        RegisterIndex_8,
        RegisterIndex_8,
        "R15B, R8B",
        &.{ 0x45, 0x88, 0xC7 },
        mov.rm8_r8,
        .R15B,
        .R8B,
    );
}

test "MOV 8 bit invalid combinations" {
    // High byte registers cannot be used with REX prefix
    var buffer: [0]u8 = undefined;

    var writer = std.io.Writer.fixed(&buffer);

    eprintf("Testing \"AH, SPL\" invalid combination:\n", .{});
    const mov_ah_spl = mov.rm8_r8(&writer, .AH, .SPL);
    try std.testing.expectError(EncodingError.InvalidOperand, mov_ah_spl);

    eprintf("Testing \"BH, R8B\" invalid combination:\n", .{});
    const mov_spl_ah = mov.rm8_r8(&writer, .SPL, .AH);
    try std.testing.expectError(EncodingError.InvalidOperand, mov_spl_ah);

    eprintf("Testing \"BH, R8B\" invalid combination:\n", .{});
    const mov_bh_r8b = mov.rm8_r8(&writer, .BH, .R8B);
    try std.testing.expectError(EncodingError.InvalidOperand, mov_bh_r8b);

    eprintf("Testing \"R8B, BH\" invalid combination:\n", .{});
    const mov_r8b_bh = mov.rm8_r8(&writer, .R8B, .BH);
    try std.testing.expectError(EncodingError.InvalidOperand, mov_r8b_bh);
}

test "MOV 16 bit registers" {
    // 66 89 c8                mov    ax,cx
    // 66 89 d3                mov    bx,dx
    // 66 89 fe                mov    si,di
    // 66 89 c7                mov    di,ax

    try validate(
        RegisterIndex_16,
        RegisterIndex_16,
        "AX, CX",
        &.{ 0x66, 0x89, 0xC8 },
        mov.rm16_r16,
        .AX,
        .CX,
    );

    try validate(
        RegisterIndex_16,
        RegisterIndex_16,
        "BX, DX",
        &.{ 0x66, 0x89, 0xD3 },
        mov.rm16_r16,
        .BX,
        .DX,
    );

    try validate(
        RegisterIndex_16,
        RegisterIndex_16,
        "SI, DI",
        &.{ 0x66, 0x89, 0xFE },
        mov.rm16_r16,
        .SI,
        .DI,
    );

    try validate(
        RegisterIndex_16,
        RegisterIndex_16,
        "DI, AX",
        &.{ 0x66, 0x89, 0xC7 },
        mov.rm16_r16,
        .DI,
        .AX,
    );
}

test "MOV 16 bit registers extended" {
    // 66 41 89 c0             mov    r8w,ax
    // 66 44 89 cb             mov    bx,r9w
    // 66 45 89 da             mov    r10w,r11w
    // 66 45 89 c7             mov    r15w,r8w

    try validate(
        RegisterIndex_16,
        RegisterIndex_16,
        "R8W, AX",
        &.{ 0x66, 0x41, 0x89, 0xC0 },
        mov.rm16_r16,
        .R8W,
        .AX,
    );

    try validate(
        RegisterIndex_16,
        RegisterIndex_16,
        "BX, R9W",
        &.{ 0x66, 0x44, 0x89, 0xCB },
        mov.rm16_r16,
        .BX,
        .R9W,
    );

    try validate(
        RegisterIndex_16,
        RegisterIndex_16,
        "R10W, R11W",
        &.{ 0x66, 0x45, 0x89, 0xDA },
        mov.rm16_r16,
        .R10W,
        .R11W,
    );

    try validate(
        RegisterIndex_16,
        RegisterIndex_16,
        "R15W, R8W",
        &.{ 0x66, 0x45, 0x89, 0xC7 },
        mov.rm16_r16,
        .R15W,
        .R8W,
    );
}

test "MOV 32 bit registers" {
    // 89 c8                   mov    eax,ecx
    // 89 d3                   mov    ebx,edx
    // 89 fe                   mov    esi,edi
    // 89 c7                   mov    edi,eax

    try validate(
        RegisterIndex_32,
        RegisterIndex_32,
        "EAX, ECX",
        &.{ 0x89, 0xC8 },
        mov.rm32_r32,
        .EAX,
        .ECX,
    );

    try validate(
        RegisterIndex_32,
        RegisterIndex_32,
        "EBX, EDX",
        &.{ 0x89, 0xD3 },
        mov.rm32_r32,
        .EBX,
        .EDX,
    );

    try validate(
        RegisterIndex_32,
        RegisterIndex_32,
        "ESI, EDI",
        &.{ 0x89, 0xFE },
        mov.rm32_r32,
        .ESI,
        .EDI,
    );

    try validate(
        RegisterIndex_32,
        RegisterIndex_32,
        "EDI, EAX",
        &.{ 0x89, 0xC7 },
        mov.rm32_r32,
        .EDI,
        .EAX,
    );
}

test "MOV 32 bit registers extended" {
    // 41 89 c0                mov    r8d,eax
    // 44 89 cb                mov    ebx,r9d
    // 45 89 da                mov    r10d,r11d
    // 45 89 c7                mov    r15d,r8d

    try validate(
        RegisterIndex_32,
        RegisterIndex_32,
        "R8D, EAX",
        &.{ 0x41, 0x89, 0xC0 },
        mov.rm32_r32,
        .R8D,
        .EAX,
    );

    try validate(
        RegisterIndex_32,
        RegisterIndex_32,
        "EBX, R9D",
        &.{ 0x44, 0x89, 0xCB },
        mov.rm32_r32,
        .EBX,
        .R9D,
    );

    try validate(
        RegisterIndex_32,
        RegisterIndex_32,
        "R10D, R11D",
        &.{ 0x45, 0x89, 0xDA },
        mov.rm32_r32,
        .R10D,
        .R11D,
    );

    try validate(
        RegisterIndex_32,
        RegisterIndex_32,
        "R15D, R8D",
        &.{ 0x45, 0x89, 0xC7 },
        mov.rm32_r32,
        .R15D,
        .R8D,
    );
}

test "MOV 64 bit registers" {
    // 48 89 c8                mov    rax,rcx
    // 48 89 d3                mov    rbx,rdx
    // 48 89 fe                mov    rsi,rdi
    // 48 89 c7                mov    rdi,rax

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "RAX, RCX",
        &.{ 0x48, 0x89, 0xC8 },
        mov.rm64_r64,
        .RAX,
        .RCX,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "RBX, RDX",
        &.{ 0x48, 0x89, 0xD3 },
        mov.rm64_r64,
        .RBX,
        .RDX,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "RSI, RDI",
        &.{ 0x48, 0x89, 0xFE },
        mov.rm64_r64,
        .RSI,
        .RDI,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "RDI, RAX",
        &.{ 0x48, 0x89, 0xC7 },
        mov.rm64_r64,
        .RDI,
        .RAX,
    );
}

test "MOV 64 bit registers extended" {
    // 49 89 c0                mov    r8,rax
    // 4c 89 c0                mov    rax,r8
    // 4d 89 c8                mov    r8,r9
    // 4d 89 da                mov    r10,r11
    // 4d 89 c7                mov    r15,r8
    // 49 89 f8                mov    r8,rdi
    // 4c 89 c7                mov    rdi,r8
    // 4d 89 ec                mov    r12,r13

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "R8, RAX",
        &.{ 0x49, 0x89, 0xC0 },
        mov.rm64_r64,
        .R8,
        .RAX,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "RAX, R8",
        &.{ 0x4C, 0x89, 0xC0 },
        mov.rm64_r64,
        .RAX,
        .R8,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "R8, R9",
        &.{ 0x4D, 0x89, 0xC8 },
        mov.rm64_r64,
        .R8,
        .R9,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "R10, R11",
        &.{ 0x4D, 0x89, 0xDA },
        mov.rm64_r64,
        .R10,
        .R11,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "R15, R8",
        &.{ 0x4D, 0x89, 0xC7 },
        mov.rm64_r64,
        .R15,
        .R8,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "R8, RDI",
        &.{ 0x49, 0x89, 0xF8 },
        mov.rm64_r64,
        .R8,
        .RDI,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "RDI, R8",
        &.{ 0x4C, 0x89, 0xC7 },
        mov.rm64_r64,
        .RDI,
        .R8,
    );

    try validate(
        RegisterIndex_64,
        RegisterIndex_64,
        "R12, R13",
        &.{ 0x4D, 0x89, 0xEC },
        mov.rm64_r64,
        .R12,
        .R13,
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
        RegisterIndex_8,
        u8,
        "R8B, 0x42 // Using MOV r/m8, imm8 encoding",
        &.{ 0x41, 0xC6, 0xC0, 0x42 },
        mov.rm8_imm8,
        .R8B,
        0x42,
    );
}

test "MOV 16 bit immediate to register" {
    // 66 b8 ff 00             mov    ax,0x00_ff
    // 66 b9 ff f0             mov    cx,0xf0_ff
    // 66 bf 34 12             mov    di,0x12_34
    // 66 bc ff ef             mov    sp,0xef_ff

    try validate(
        RegisterIndex_16,
        u16,
        "AX, 0xFF",
        &.{ 0x66, 0xB8, 0xFF, 0x00 },
        mov.r16_imm16,
        .AX,
        0xFF,
    );

    try validate(
        RegisterIndex_16,
        u16,
        "CX, 0xF0_FF",
        &.{ 0x66, 0xB9, 0xFF, 0xF0 },
        mov.r16_imm16,
        .CX,
        0xF0FF,
    );

    try validate(
        RegisterIndex_16,
        u16,
        "DI, 0x12_34",
        &.{ 0x66, 0xBF, 0x34, 0x12 },
        mov.r16_imm16,
        .DI,
        0x1234,
    );

    try validate(
        RegisterIndex_16,
        u16,
        "SP, 0xEF_FF",
        &.{ 0x66, 0xBC, 0xFF, 0xEF },
        mov.r16_imm16,
        .SP,
        0xEFFF,
    );
}

test "MOV 16 bit immediate to register extended" {
    // 66 41 b8 34 12          mov    r8w,0x12_34
    // 66 41 bf ff ef          mov    r15w,0xef_ff
    // 66 41 b9 00 00          mov    r9w,0x00_00
    // 66 41 bc 0f 0f          mov    r12w,0x0f_0f
    // 66 41 bd f0 f0          mov    r13w,0xf0_f0

    try validate(
        RegisterIndex_16,
        u16,
        "R8W, 0x12_34",
        &.{ 0x66, 0x41, 0xB8, 0x34, 0x12 },
        mov.r16_imm16,
        .R8W,
        0x1234,
    );

    try validate(
        RegisterIndex_16,
        u16,
        "R15W, 0xEF_FF",
        &.{ 0x66, 0x41, 0xBF, 0xFF, 0xEF },
        mov.r16_imm16,
        .R15W,
        0xEFFF,
    );

    try validate(
        RegisterIndex_16,
        u16,
        "R9W, 0x00_00",
        &.{ 0x66, 0x41, 0xB9, 0x00, 0x00 },
        mov.r16_imm16,
        .R9W,
        0x0000,
    );

    try validate(
        RegisterIndex_16,
        u16,
        "R12W, 0x0F_0F",
        &.{ 0x66, 0x41, 0xBC, 0x0F, 0x0F },
        mov.r16_imm16,
        .R12W,
        0x0F0F,
    );

    try validate(
        RegisterIndex_16,
        u16,
        "R13W, 0xF0_F0",
        &.{ 0x66, 0x41, 0xBD, 0xF0, 0xF0 },
        mov.r16_imm16,
        .R13W,
        0xF0F0,
    );
}

test "MOV 32bit immediate to register" {
    // 41 b8 34 12 34 12       mov    r8d,0x12_34_12_34
    // 41 bf ef ef ef ef       mov    r15d,0xef_ef_ef_ef
    // 41 bc 00 00 00 00       mov    r12d,0x00_00_00_00
    // 41 bd 0f 0f 0f 0f       mov    r13d,0x0f_0f_0f_0f
    // 41 b9 ff 00 00 00       mov    r9d,0x00_00_00_ff

    try validate(
        RegisterIndex_32,
        u32,
        "R8D, 0x12_34_12_34",
        &.{ 0x41, 0xB8, 0x34, 0x12, 0x34, 0x12 },
        mov.r32_imm32,
        .R8D,
        0x12341234,
    );

    try validate(
        RegisterIndex_32,
        u32,
        "R15D, 0xEF_EF_EF_EF",
        &.{ 0x41, 0xBF, 0xEF, 0xEF, 0xEF, 0xEF },
        mov.r32_imm32,
        .R15D,
        0xEFEFEFEF,
    );

    try validate(
        RegisterIndex_32,
        u32,
        "R12D, 0x00_00_00_00",
        &.{ 0x41, 0xBC, 0x00, 0x00, 0x00, 0x00 },
        mov.r32_imm32,
        .R12D,
        0x00000000,
    );

    try validate(
        RegisterIndex_32,
        u32,
        "R13D, 0x0F_0F_0F_0F",
        &.{ 0x41, 0xBD, 0x0F, 0x0F, 0x0F, 0x0F },
        mov.r32_imm32,
        .R13D,
        0x0F0F0F0F,
    );

    try validate(
        RegisterIndex_32,
        u32,
        "R9D, 0x00_00_00_FF",
        &.{ 0x41, 0xB9, 0xFF, 0x00, 0x00, 0x00 },
        mov.r32_imm32,
        .R9D,
        0x000000FF,
    );
}

test "MOV 64 bit immediate to register" {
    // 48 c7 c7 ff 00 00 00             mov    rdi,0xff
    // 48 c7 c0 0c 00 00 00             mov    rax,0xc
    // 48 c7 c2 f4 ff ff ff             mov    rdx,0xfffffffffffffff4
    // 48 be ff ff ff ff 00 00 00 00    movabs rsi,0xffffffff
    // 48 b8 bc 9a 78 56 34 12 ff ef    movabs rax,0xefff_1234_5678_9ABC

    try validate(
        RegisterIndex_64,
        u64,
        "RDI, 0xFF",
        &.{ 0x48, 0xC7, 0xC7, 0xFF, 0x00, 0x00, 0x00 },
        mov.r64_imm64_auto,
        .RDI,
        0x0000_0000_0000_00FF,
    );

    try validate(
        RegisterIndex_64,
        u64,
        "RAX, 0x0C",
        &.{ 0x48, 0xC7, 0xC0, 0x0C, 0x00, 0x00, 0x00 },
        mov.r64_imm64_auto,
        .RAX,
        0x0000_0000_0000_000C,
    );

    try validate(
        RegisterIndex_64,
        u64,
        "RDX, -12",
        &.{ 0x48, 0xC7, 0xC2, 0xF4, 0xFF, 0xFF, 0xFF },
        mov.r64_imm64_auto,
        .RDX,
        0xFFFF_FFFF_FFFF_FFF4,
    );

    try validate(
        RegisterIndex_64,
        u64,
        "RSI, 0xFFFF_FFFF",
        &.{ 0x48, 0xBE, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00 },
        mov.r64_imm64_auto,
        .RSI,
        0x0000_0000_FFFF_FFFF,
    );

    try validate(
        RegisterIndex_64,
        u64,
        "RAX, 0xEFFF_1234_1234_1234",
        &.{ 0x48, 0xB8, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12, 0xFF, 0xEF },
        mov.r64_imm64_auto,
        .RAX,
        0xEFFF_1234_5678_9ABC,
    );
}

test "MOV 64 bit immediate to register extended" {
    // 49 b8 34 12 34 12 34 12 34 12    movabs r8,0x1234123412341234
    // 49 bf 34 12 34 12 34 12 ff ef    movabs r15,0xefff123412341234
    // 49 c7 c4 00 00 00 00             mov    r12,0x0
    // 49 bd f0 de bc 9a 78 56 34 12    movabs r13,0x1234_5678_9abc_def0

    try validate(
        RegisterIndex_64,
        u64,
        "R8, 0x1234_1234_1234_1234",
        &.{ 0x49, 0xB8, 0x34, 0x12, 0x34, 0x12, 0x34, 0x12, 0x34, 0x12 },
        mov.r64_imm64_auto,
        .R8,
        0x1234_1234_1234_1234,
    );

    try validate(
        RegisterIndex_64,
        u64,
        "R15, 0xEFFF_1234_1234_1234",
        &.{ 0x49, 0xBF, 0x34, 0x12, 0x34, 0x12, 0x34, 0x12, 0xFF, 0xEF },
        mov.r64_imm64_auto,
        .R15,
        0xEFFF_1234_1234_1234,
    );

    try validate(
        RegisterIndex_64,
        u64,
        "R12, 0x0",
        &.{ 0x49, 0xC7, 0xC4, 0x00, 0x00, 0x00, 0x00 },
        mov.r64_imm64_auto,
        .R12,
        0x0000_0000_0000_0000,
    );

    try validate(
        RegisterIndex_64,
        u64,
        "R13, 0xF0F0_F0F0_F0F0_F000",
        &.{ 0x49, 0xBD, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12 },
        mov.r64_imm64_auto,
        .R13,
        0x1234_5678_9ABC_DEF0,
    );
}
