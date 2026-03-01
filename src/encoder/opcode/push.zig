//! Encoder module for PUSH instruction forms.
//! This is built from https://www.felixcloutier.com/x86/push

const std = @import("std");

const error_file = @import("../error.zig");
const EncodingError = error_file.EncodingError;

const helper_file = @import("../helper.zig");
const extractBits = helper_file.extractBits;

const factory_file = @import("../factory.zig");
const rex_bytes = factory_file.rex_bytes;

const register = @import("../reg.zig");
const BIT32_ADDRESSING_PREFIX = register.BIT32_ADDRESSING_PREFIX;
const emit_modrm_sib = register.emit_modrm_sib;

const Register64 = register.RegisterIndex_64;
const RegisterMemory64 = register.RegisterMemory_64;

const Writer = std.io.Writer;
const Register16_LegacyPrefix: u8 = 0x66;

const PUSH_OPCODE = struct {
    const PUSH_R64_BASE: u8 = 0x50; // +rd
    const PUSH_RM64: u8 = 0xFF; // /6
    const PUSH_GROUP_DIGIT: u3 = 0b110;

    const PUSH_IMM8: u8 = 0x6A;
    const PUSH_IMM32: u8 = 0x68;
};

inline fn write_byte(writer: *Writer, byte: u8) EncodingError!void {
    writer.writeByte(byte) catch {
        return EncodingError.WriterError;
    };
}

inline fn write_bytes(writer: *Writer, bytes: []const u8) EncodingError!void {
    writer.writeAll(bytes) catch {
        return EncodingError.WriterError;
    };
}

fn emit_imm(
    comptime T: type,
    writer: *Writer,
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

/// push r64
pub fn r64(writer: *Writer, dest: Register64) EncodingError!usize {
    var written: usize = 0;

    if (dest.is_extended()) {
        const rex = rex_bytes(false, false, false, true);
        written += 1;
        try write_byte(writer, rex);
    }

    const opcode = PUSH_OPCODE.PUSH_R64_BASE | (dest.reg_low3() & 0x7);
    written += 1;
    try write_byte(writer, opcode);

    return written;
}

/// push r/m64 (FF /6)
pub fn rm64(writer: *Writer, dest: RegisterMemory64) EncodingError!usize {
    var written: usize = 0;

    if (dest.is_memory32()) {
        written += 1;
        try write_byte(writer, BIT32_ADDRESSING_PREFIX);
    }

    if (dest.rex_b() or dest.rex_x()) {
        const rex = rex_bytes(false, false, dest.rex_x(), dest.rex_b());
        written += 1;
        try write_byte(writer, rex);
    }

    written += 1;
    try write_byte(writer, PUSH_OPCODE.PUSH_RM64);

    written += try emit_modrm_sib(
        u3,
        RegisterMemory64,
        writer,
        PUSH_OPCODE.PUSH_GROUP_DIGIT,
        dest,
    );

    return written;
}

/// push imm8 (sign-extended by CPU)
pub fn imm8(writer: *Writer, value: i8) EncodingError!usize {
    return emit_imm(i8, writer, PUSH_OPCODE.PUSH_IMM8, false, value);
}

/// push imm16
pub fn imm16(writer: *Writer, value: u16) EncodingError!usize {
    return emit_imm(u16, writer, PUSH_OPCODE.PUSH_IMM32, true, value);
}

/// push imm32 (sign-extended by CPU in long mode)
pub fn imm32(writer: *Writer, value: u32) EncodingError!usize {
    return emit_imm(u32, writer, PUSH_OPCODE.PUSH_IMM32, false, value);
}
