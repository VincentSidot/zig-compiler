//! Encoder module for PUSH instruction forms.
//! This is built from https://www.felixcloutier.com/x86/push

const std = @import("std");

const error_file = @import("../error.zig");
const EncodingError = error_file.EncodingError;

const helper_file = @import("../helper.zig");
const extractBits = helper_file.extractBits;

const factory_file = @import("../factory.zig");
const factory_single = factory_file.factory_single;
const rex_bytes = factory_file.rex_bytes;
const write_byte = factory_file.write_byte;
const write_bytes = factory_file.write_bytes;

const register = @import("../reg.zig");
const BIT32_ADDRESSING_PREFIX = register.BIT32_ADDRESSING_PREFIX;
const emit_modrm_sib = register.emit_modrm_sib;

const Register16 = register.RegisterIndex_16;
const Register32 = register.RegisterIndex_32;
const Register64 = register.RegisterIndex_64;
const RegisterMemory16 = register.RegisterMemory_16;
const RegisterMemory32 = register.RegisterMemory_32;
const RegisterMemory64 = register.RegisterMemory_64;

const Writer = std.Io.Writer;
const Register16_LegacyPrefix: u8 = 0x66;

const PUSH_OPCODE = struct {
    const PUSH_REG: u8 = 0x50; // +rd
    const PUSH_M: u8 = 0xFF; // /6

    const PUSH_IMM8: u8 = 0x6A;
    const PUSH_IMM32: u8 = 0x68;
};

fn emit_imm(
    comptime T: type,
    writer: ?*Writer,
    opcode: u8,
    operand_prefix_66: bool,
    value: T,
) EncodingError!usize {
    var written: usize = 0;

    if (operand_prefix_66) {
        written += 1;
        try write_byte(writer, Register16_LegacyPrefix);
    }

    written += 1;
    try write_byte(writer, opcode);

    const imm = extractBits(T, value);
    written += @sizeOf(T);
    try write_bytes(writer, &imm);

    return written;
}

/// push r16/r32/r64
pub const r16 = factory_single(
    Register16,
    0, // Unused
    PUSH_OPCODE.PUSH_REG,
);
pub const r32 = factory_single(
    Register32,
    0, // Unused
    PUSH_OPCODE.PUSH_REG,
);
pub const r64 = factory_single(
    Register64,
    0, // Unused
    PUSH_OPCODE.PUSH_REG,
);

pub const rm16 = factory_single(
    RegisterMemory16,
    0b110, // /6
    PUSH_OPCODE.PUSH_M,
);
pub const rm32 = factory_single(
    RegisterMemory32,
    0b110, // /6
    PUSH_OPCODE.PUSH_M,
);
pub const rm64 = factory_single(
    RegisterMemory64,
    0b110, // /6
    PUSH_OPCODE.PUSH_M,
);

/// push imm8 (sign-extended by CPU)
pub fn imm8(writer: ?*Writer, value: i8) EncodingError!usize {
    return emit_imm(i8, writer, PUSH_OPCODE.PUSH_IMM8, false, value);
}

/// push imm16
pub fn imm16(writer: ?*Writer, value: u16) EncodingError!usize {
    return emit_imm(u16, writer, PUSH_OPCODE.PUSH_IMM32, true, value);
}

/// push imm32 (sign-extended by CPU in long mode)
pub fn imm32(writer: ?*Writer, value: u32) EncodingError!usize {
    return emit_imm(u32, writer, PUSH_OPCODE.PUSH_IMM32, false, value);
}
