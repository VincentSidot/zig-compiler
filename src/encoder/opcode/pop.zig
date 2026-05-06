//! Encoder module for POP instruction forms.
//! This is built from https://www.felixcloutier.com/x86/pop

const std = @import("std");

const error_file = @import("../error.zig");
const EncodingError = error_file.EncodingError;

const factory_file = @import("../factory.zig");
const rex_bytes = factory_file.rex_bytes;

const register = @import("../reg.zig");
const BIT32_ADDRESSING_PREFIX = register.BIT32_ADDRESSING_PREFIX;
const emit_modrm_sib = register.emit_modrm_sib;

const Register64 = register.RegisterIndex_64;
const RegisterMemory64 = register.RegisterMemory_64;

const Writer = std.Io.Writer;

const POP_OPCODE = struct {
    const POP_R64_BASE: u8 = 0x58; // +rd
    const POP_RM64: u8 = 0x8F; // /0
    const POP_GROUP_DIGIT: u3 = 0b000;
};

inline fn write_byte(writer: *Writer, byte: u8) EncodingError!void {
    writer.writeByte(byte) catch {
        return EncodingError.WriterError;
    };
}

/// pop r64
pub fn r64(writer: *Writer, dest: Register64) EncodingError!usize {
    var written: usize = 0;

    if (dest.is_extended()) {
        const rex = rex_bytes(false, false, false, true);
        written += 1;
        try write_byte(writer, rex);
    }

    const opcode = POP_OPCODE.POP_R64_BASE | (dest.reg_low3() & 0x7);
    written += 1;
    try write_byte(writer, opcode);

    return written;
}

/// pop r/m64 (8F /0)
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
    try write_byte(writer, POP_OPCODE.POP_RM64);

    written += try emit_modrm_sib(
        u3,
        RegisterMemory64,
        writer,
        POP_OPCODE.POP_GROUP_DIGIT,
        dest,
    );

    return written;
}
