//! Encoder module for encoding assembly instructions.
//! This module provides a simple interface for encoding MOV instructions
//! This is built from https://www.felixcloutier.com/x86/mov

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

fn fits_signext32_range(value: u64) bool {
    const MAX_POS: u64 = 0x0000_0000_7FFF_FFFF; // 2^31 - 1
    const MIN_NEG: u64 = 0xFFFF_FFFF_8000_0000; // -2^31 in two's complement

    return value <= MAX_POS or value >= MIN_NEG;
}

const MOV_OPCODE = struct {
    const MOV_RM8_R8: u8 = 0x88;
    const MOV_RM16_R16: u8 = 0x89;
    const MOV_RM32_R32: u8 = 0x89;
    const MOV_RM64_R64: u8 = 0x89;

    const MOV_R8_RM8: u8 = 0x8A;
    const MOV_R16_RM16: u8 = 0x8B;
    const MOV_R32_RM32: u8 = 0x8B;
    const MOV_R64_RM64: u8 = 0x8B;

    const MOV_R8_IMM8: u8 = 0xB0;
    const MOV_R16_IMM16: u8 = 0xB8;
    const MOV_R32_IMM32: u8 = 0xB8;
    const MOV_R64_IMM64: u8 = 0xB8;

    const MOV_RM8_IMM8: u8 = 0xC6;
    const MOV_RM16_IMM16: u8 = 0xC7;
    const MOV_RM32_IMM32: u8 = 0xC7;
    const MOV_RM64_IMM64: u8 = 0xC7;
};

const Writer = std.io.Writer;

pub const mov = struct {
    // This won't compile for now - it's okay since we are working on the factory logic for now.

    pub const rm8_r8 = factory_op(
        RegisterMemory8,
        Register8,
        MOV_OPCODE.MOV_RM8_R8,
    );
    pub const r8_rm8 = factory_op(Register8, RegisterMemory8, MOV_OPCODE.MOV_R8_RM8);
    pub const rm8_imm8 = factory_imm(
        RegisterMemory8,
        u8,
        .{ .mode = .modrm_group, .opcode = MOV_OPCODE.MOV_RM8_IMM8, .modrm_reg = 0b000 },
    );
    pub const r8_imm8 = factory_imm(
        Register8,
        u8,
        .{ .mode = .opcode_plus_reg, .opcode = MOV_OPCODE.MOV_R8_IMM8 },
    );

    pub const rm16_r16 = factory_op(RegisterMemory16, Register16, MOV_OPCODE.MOV_RM16_R16);
    pub const r16_rm16 = factory_op(Register16, RegisterMemory16, MOV_OPCODE.MOV_R16_RM16);
    pub const rm16_imm16 = factory_imm(
        RegisterMemory16,
        u16,
        .{ .mode = .modrm_group, .opcode = MOV_OPCODE.MOV_RM16_IMM16, .modrm_reg = 0b000 },
    );
    pub const r16_imm16 = factory_imm(
        Register16,
        u16,
        .{ .mode = .opcode_plus_reg, .opcode = MOV_OPCODE.MOV_R16_IMM16 },
    );

    pub const rm32_r32 = factory_op(RegisterMemory32, Register32, MOV_OPCODE.MOV_RM32_R32);
    pub const r32_rm32 = factory_op(Register32, RegisterMemory32, MOV_OPCODE.MOV_R32_RM32);
    pub const rm32_imm32 = factory_imm(
        RegisterMemory32,
        u32,
        .{ .mode = .modrm_group, .opcode = MOV_OPCODE.MOV_RM32_IMM32, .modrm_reg = 0b000 },
    );
    pub const r32_imm32 = factory_imm(
        Register32,
        u32,
        .{ .mode = .opcode_plus_reg, .opcode = MOV_OPCODE.MOV_R32_IMM32 },
    );

    pub const rm64_r64 = factory_op(RegisterMemory64, Register64, MOV_OPCODE.MOV_RM64_R64);
    pub const r64_rm64 = factory_op(Register64, RegisterMemory64, MOV_OPCODE.MOV_R64_RM64);
    pub const rm64_imm32 = factory_imm(
        RegisterMemory64,
        u32,
        .{ .mode = .modrm_group, .opcode = MOV_OPCODE.MOV_RM64_IMM64, .modrm_reg = 0b000 },
    );
    pub const r64_imm64 = factory_imm(
        Register64,
        u64,
        .{ .mode = .opcode_plus_reg, .opcode = MOV_OPCODE.MOV_R64_IMM64 },
    );

    pub fn r64_imm64_auto(writer: *Writer, dest: Register64, source: u64) EncodingError!usize {
        if (fits_signext32_range(source)) {
            var converted: u32 = undefined;

            if (source <= 0x7FFF_FFFF) {
                converted = @intCast(source);
            } else {
                // Convert to two's complement negative value
                const shifted = source - 0x1_0000_0000;
                converted = @intCast(shifted & 0xFFFF_FFFF);
            }

            return mov.rm64_imm32(writer, RegisterMemory64{ .reg = dest }, converted);
        } else {
            return mov.r64_imm64(writer, dest, source);
        }
    }
};
