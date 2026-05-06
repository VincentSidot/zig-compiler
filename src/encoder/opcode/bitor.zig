//! Encoder module for OR instruction forms.
//! This is built from https://www.felixcloutier.com/x86/or

const std = @import("std");

const error_file = @import("../error.zig");
const EncodingError = error_file.EncodingError;

const factory_file = @import("../factory.zig");
const factory_op = factory_file.factory_op;
const factory_imm = factory_file.factory_imm;

const register = @import("../reg.zig");

const Register64 = register.RegisterIndex_64;
const Register32 = register.RegisterIndex_32;
const Register16 = register.RegisterIndex_16;
const Register8 = register.RegisterIndex_8;

const RegisterMemory64 = register.RegisterMemory_64;
const RegisterMemory32 = register.RegisterMemory_32;
const RegisterMemory16 = register.RegisterMemory_16;
const RegisterMemory8 = register.RegisterMemory_8;

const OR_OPCODE = struct {
    const OR_RM8_R8: u8 = 0x08;
    const OR_RM16_R16: u8 = 0x09;
    const OR_RM32_R32: u8 = 0x09;
    const OR_RM64_R64: u8 = 0x09;

    const OR_R8_RM8: u8 = 0x0A;
    const OR_R16_RM16: u8 = 0x0B;
    const OR_R32_RM32: u8 = 0x0B;
    const OR_R64_RM64: u8 = 0x0B;

    const OR_RM8_IMM8: u8 = 0x80; // /1
    const OR_RM16_IMM16: u8 = 0x81; // /1
    const OR_RM32_IMM32: u8 = 0x81; // /1
    const OR_RM64_IMM32: u8 = 0x81; // /1 + REX.W
};

const Writer = std.Io.Writer;

pub const rm8_r8 = factory_op(RegisterMemory8, Register8, OR_OPCODE.OR_RM8_R8);
pub const r8_rm8 = factory_op(Register8, RegisterMemory8, OR_OPCODE.OR_R8_RM8);

pub const rm16_r16 = factory_op(RegisterMemory16, Register16, OR_OPCODE.OR_RM16_R16);
pub const r16_rm16 = factory_op(Register16, RegisterMemory16, OR_OPCODE.OR_R16_RM16);

pub const rm32_r32 = factory_op(RegisterMemory32, Register32, OR_OPCODE.OR_RM32_R32);
pub const r32_rm32 = factory_op(Register32, RegisterMemory32, OR_OPCODE.OR_R32_RM32);

pub const rm64_r64 = factory_op(RegisterMemory64, Register64, OR_OPCODE.OR_RM64_R64);
pub const r64_rm64 = factory_op(Register64, RegisterMemory64, OR_OPCODE.OR_R64_RM64);

pub const rm8_imm8 = factory_imm(
    RegisterMemory8,
    u8,
    .{ .mode = .modrm_group, .opcode = OR_OPCODE.OR_RM8_IMM8, .modrm_reg = 0b001 },
);
pub const rm16_imm16 = factory_imm(
    RegisterMemory16,
    u16,
    .{ .mode = .modrm_group, .opcode = OR_OPCODE.OR_RM16_IMM16, .modrm_reg = 0b001 },
);
pub const rm32_imm32 = factory_imm(
    RegisterMemory32,
    u32,
    .{ .mode = .modrm_group, .opcode = OR_OPCODE.OR_RM32_IMM32, .modrm_reg = 0b001 },
);
pub const rm64_imm32 = factory_imm(
    RegisterMemory64,
    u32,
    .{ .mode = .modrm_group, .opcode = OR_OPCODE.OR_RM64_IMM32, .modrm_reg = 0b001 },
);

pub fn r8_imm8(writer: *Writer, dest: Register8, source: u8) EncodingError!usize {
    return rm8_imm8(writer, RegisterMemory8{ .reg = dest }, source);
}

pub fn r16_imm16(writer: *Writer, dest: Register16, source: u16) EncodingError!usize {
    return rm16_imm16(writer, RegisterMemory16{ .reg = dest }, source);
}

pub fn r32_imm32(writer: *Writer, dest: Register32, source: u32) EncodingError!usize {
    return rm32_imm32(writer, RegisterMemory32{ .reg = dest }, source);
}

pub fn r64_imm32(writer: *Writer, dest: Register64, source: u32) EncodingError!usize {
    return rm64_imm32(writer, RegisterMemory64{ .reg = dest }, source);
}
