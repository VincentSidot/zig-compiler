//! Encoder module for CALL instruction forms.
//! This is built from https://www.felixcloutier.com/x86/call

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

const CALL_OPCODE = struct {
    const CALL_REL32: u8 = 0xE8; // call rel32
    const CALL_RM64: u8 = 0xFF; // /2
    const CALL_GROUP_DIGIT: u3 = 0b010;
};

/// call rel32
/// disp is relative to the next instruction.
pub fn rel32(writer: *Writer, disp: i32) EncodingError!usize {
    var written: usize = 0;

    written += 1;
    writer.writeByte(CALL_OPCODE.CALL_REL32) catch {
        return EncodingError.WriterError;
    };

    const disp32 = extractBits(i32, disp);
    written += 4;
    writer.writeAll(&disp32) catch {
        return EncodingError.WriterError;
    };

    return written;
}

/// Backpatch a `call rel32` encoded at `op_addr`.
/// `patch_value` is the absolute target address (within `buffer`) to call.
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

/// call r/m64 (FF /2)
pub fn rm64(writer: *Writer, dest: RegisterMemory64) EncodingError!usize {
    var written: usize = 0;

    if (dest.is_memory32()) {
        written += 1;
        writer.writeByte(BIT32_ADDRESSING_PREFIX) catch {
            return EncodingError.WriterError;
        };
    }

    if (dest.rex_b() or dest.rex_x()) {
        const rex = rex_bytes(false, false, dest.rex_x(), dest.rex_b());
        written += 1;
        writer.writeByte(rex) catch {
            return EncodingError.WriterError;
        };
    }

    written += 1;
    writer.writeByte(CALL_OPCODE.CALL_RM64) catch {
        return EncodingError.WriterError;
    };

    written += try emit_modrm_sib(
        u3,
        RegisterMemory64,
        writer,
        CALL_OPCODE.CALL_GROUP_DIGIT,
        dest,
    );

    return written;
}

/// call r64
pub fn r64(writer: *Writer, dest: Register64) EncodingError!usize {
    return rm64(writer, RegisterMemory64{ .reg = dest });
}
