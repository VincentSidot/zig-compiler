//! Encoder module for JMP instruction forms.
//! This is built from https://www.felixcloutier.com/x86/jmp

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

const Writer = std.Io.Writer;

const JMP_OPCODE = struct {
    const JMP_REL8: u8 = 0xEB;
    const JMP_REL32: u8 = 0xE9;
    const JMP_RM64: u8 = 0xFF; // /4
    const JMP_GROUP_DIGIT: u3 = 0b100;
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

/// jmp rel8
pub fn rel8(writer: *Writer, disp: i8) EncodingError!usize {
    var written: usize = 0;

    written += 1;
    try write_byte(writer, JMP_OPCODE.JMP_REL8);

    const imm = extractBits(i8, disp);
    written += 1;
    try write_bytes(writer, &imm);

    return written;
}

/// jmp rel32
pub fn rel32(writer: *Writer, disp: i32) EncodingError!usize {
    var written: usize = 0;

    written += 1;
    try write_byte(writer, JMP_OPCODE.JMP_REL32);

    const imm = extractBits(i32, disp);
    written += 4;
    try write_bytes(writer, &imm);

    return written;
}

/// Backpatch a `jmp rel8` encoded at `op_addr`.
/// `patch_value` is the absolute target address (within `buffer`) to jump to.
pub fn patch_rel8(buffer: []u8, op_addr: usize, patch_value: usize) EncodingError!void {
    if (op_addr + 2 > buffer.len) {
        return EncodingError.InvalidPatchAddress;
    }

    const next_ip = op_addr + 2;
    const delta: i64 = @as(i64, @intCast(patch_value)) - @as(i64, @intCast(next_ip));
    const disp: i8 = std.math.cast(i8, delta) orelse return EncodingError.InvalidDisplacement;
    const bytes = extractBits(i8, disp);
    @memcpy(buffer[op_addr + 1 .. op_addr + 2], bytes[0..]);
}

/// Backpatch a `jmp rel32` encoded at `op_addr`.
/// `patch_value` is the absolute target address (within `buffer`) to jump to.
pub fn patch_rel32(buffer: []u8, op_addr: usize, patch_value: usize) EncodingError!void {
    if (op_addr + 5 > buffer.len) {
        return EncodingError.InvalidPatchAddress;
    }

    const next_ip = op_addr + 5;
    const delta: i64 = @as(i64, @intCast(patch_value)) - @as(i64, @intCast(next_ip));
    const disp: i32 = std.math.cast(i32, delta) orelse return EncodingError.InvalidDisplacement;
    const bytes = extractBits(i32, disp);
    @memcpy(buffer[op_addr + 1 .. op_addr + 5], bytes[0..]);
}

/// jmp r/m64 (FF /4)
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
    try write_byte(writer, JMP_OPCODE.JMP_RM64);

    written += try emit_modrm_sib(
        u3,
        RegisterMemory64,
        writer,
        JMP_OPCODE.JMP_GROUP_DIGIT,
        dest,
    );

    return written;
}

/// jmp r64
pub fn r64(writer: *Writer, dest: Register64) EncodingError!usize {
    return rm64(writer, RegisterMemory64{ .reg = dest });
}
