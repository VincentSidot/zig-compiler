//! Encoder module for TEST instruction forms.
//! This is built from https://www.felixcloutier.com/x86/test

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

const TEST_OPCODE = struct {
    const TEST_RM8_R8: u8 = 0x84;
    const TEST_RM16_R16: u8 = 0x85;
    const TEST_RM32_R32: u8 = 0x85;
    const TEST_RM64_R64: u8 = 0x85;

    const TEST_RM8_IMM8: u8 = 0xF6; // /0
    const TEST_RM16_IMM16: u8 = 0xF7; // /0
    const TEST_RM32_IMM32: u8 = 0xF7; // /0
    const TEST_RM64_IMM32: u8 = 0xF7; // /0 + REX.W
};

const Writer = std.Io.Writer;

pub const rm8_r8 = factory_op(RegisterMemory8, Register8, TEST_OPCODE.TEST_RM8_R8);
pub const rm16_r16 = factory_op(RegisterMemory16, Register16, TEST_OPCODE.TEST_RM16_R16);
pub const rm32_r32 = factory_op(RegisterMemory32, Register32, TEST_OPCODE.TEST_RM32_R32);
pub const rm64_r64 = factory_op(RegisterMemory64, Register64, TEST_OPCODE.TEST_RM64_R64);

pub const rm8_imm8 = factory_imm(
    RegisterMemory8,
    u8,
    .{ .mode = .modrm_group, .opcode = TEST_OPCODE.TEST_RM8_IMM8, .modrm_reg = 0b000 },
);
pub const rm16_imm16 = factory_imm(
    RegisterMemory16,
    u16,
    .{ .mode = .modrm_group, .opcode = TEST_OPCODE.TEST_RM16_IMM16, .modrm_reg = 0b000 },
);
pub const rm32_imm32 = factory_imm(
    RegisterMemory32,
    u32,
    .{ .mode = .modrm_group, .opcode = TEST_OPCODE.TEST_RM32_IMM32, .modrm_reg = 0b000 },
);
pub const rm64_imm32 = factory_imm(
    RegisterMemory64,
    u32,
    .{ .mode = .modrm_group, .opcode = TEST_OPCODE.TEST_RM64_IMM32, .modrm_reg = 0b000 },
);

pub fn r8_imm8(writer: ?*Writer, dest: Register8, source: u8) EncodingError!usize {
    return rm8_imm8(writer, RegisterMemory8{ .reg = dest }, source);
}

pub fn r16_imm16(writer: ?*Writer, dest: Register16, source: u16) EncodingError!usize {
    return rm16_imm16(writer, RegisterMemory16{ .reg = dest }, source);
}

pub fn r32_imm32(writer: ?*Writer, dest: Register32, source: u32) EncodingError!usize {
    return rm32_imm32(writer, RegisterMemory32{ .reg = dest }, source);
}

pub fn r64_imm32(writer: ?*Writer, dest: Register64, source: u32) EncodingError!usize {
    return rm64_imm32(writer, RegisterMemory64{ .reg = dest }, source);
}
