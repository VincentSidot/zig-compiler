//! Encoder module for LEA instruction forms.
//! This is built from https://www.felixcloutier.com/x86/lea

const std = @import("std");

const error_file = @import("../error.zig");
const EncodingError = error_file.EncodingError;

const factory_file = @import("../factory.zig");
const rex_bytes = factory_file.rex_bytes;

const register = @import("../reg.zig");
const BIT32_ADDRESSING_PREFIX = register.BIT32_ADDRESSING_PREFIX;
const emit_modrm_sib = register.emit_modrm_sib;

const Register64 = register.RegisterIndex_64;
const Register32 = register.RegisterIndex_32;
const Register16 = register.RegisterIndex_16;

const RegisterMemory64 = register.RegisterMemory_64;
const RegisterMemory32 = register.RegisterMemory_32;
const RegisterMemory16 = register.RegisterMemory_16;

const Writer = std.io.Writer;
const Register16_LegacyPrefix = 0x66;

const LEA_OPCODE = struct {
    const LEA_R_M: u8 = 0x8D;
};

inline fn write_byte(writer: *Writer, byte: u8) EncodingError!void {
    writer.writeByte(byte) catch {
        return EncodingError.WriterError;
    };
}

fn encode(
    comptime Reg: type,
    comptime Mem: type,
    writer: *Writer,
    dest: Reg,
    source: Mem,
    comptime is_16bit: bool,
    comptime is_64bit: bool,
) EncodingError!usize {
    var written: usize = 0;

    switch (source) {
        .reg => {
            return EncodingError.InvalidOperand;
        },
        .mem => |_| {},
    }

    if (is_16bit) {
        written += 1;
        try write_byte(writer, Register16_LegacyPrefix);
    }

    if (source.is_memory32()) {
        written += 1;
        try write_byte(writer, BIT32_ADDRESSING_PREFIX);
    }

    if (is_64bit or dest.need_rex() or source.need_rex()) {
        const rex = rex_bytes(
            is_64bit,
            dest.is_extended(),
            source.rex_x(),
            source.rex_b(),
        );

        written += 1;
        try write_byte(writer, rex);
    }

    written += 1;
    try write_byte(writer, LEA_OPCODE.LEA_R_M);

    written += try emit_modrm_sib(Reg, Mem, writer, dest, source);

    return written;
}

/// lea r16, m
pub fn r16_m(writer: *Writer, dest: Register16, source: RegisterMemory16) EncodingError!usize {
    return encode(Register16, RegisterMemory16, writer, dest, source, true, false);
}

/// lea r32, m
pub fn r32_m(writer: *Writer, dest: Register32, source: RegisterMemory32) EncodingError!usize {
    return encode(Register32, RegisterMemory32, writer, dest, source, false, false);
}

/// lea r64, m
pub fn r64_m(writer: *Writer, dest: Register64, source: RegisterMemory64) EncodingError!usize {
    return encode(Register64, RegisterMemory64, writer, dest, source, false, true);
}
