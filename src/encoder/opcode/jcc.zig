//! Encoder module for Jcc instruction forms.
//! This is built from https://www.felixcloutier.com/x86/jcc

const std = @import("std");

const error_file = @import("../error.zig");
const EncodingError = error_file.EncodingError;

const helper_file = @import("../helper.zig");
const extractBits = helper_file.extractBits;

const Writer = std.Io.Writer;

pub const Condition = enum(u4) {
    /// Overflow
    o = 0x0,
    /// No overflow
    no = 0x1,
    /// Below (unsigned)
    b = 0x2, // c, nae
    /// Above or equal (unsigned)
    ae = 0x3, // nb, nc
    /// Equal
    e = 0x4, // z
    /// Not equal
    ne = 0x5, // nz
    /// Below or equal (unsigned)
    be = 0x6, // na
    /// Above (unsigned)
    a = 0x7, // nbe
    /// Sign
    s = 0x8,
    /// Not sign
    ns = 0x9,
    /// Parity even
    p = 0xA, // pe
    /// Parity odd
    np = 0xB, // po
    /// Less (signed)
    l = 0xC, // nge
    /// Greater or equal (signed)
    ge = 0xD, // nl
    /// Less or equal (signed)
    le = 0xE, // ng
    /// Greater (signed)
    g = 0xF, // nle
};

const JCC_OPCODE = struct {
    const JCC_REL8_BASE: u8 = 0x70; // +cc
    const JCC_REL32_ESCAPE: u8 = 0x0F;
    const JCC_REL32_BASE: u8 = 0x80; // +cc
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

/// jcc rel8
pub fn rel8(writer: *Writer, condition: Condition, disp: i8) EncodingError!usize {
    var written: usize = 0;

    const opcode = JCC_OPCODE.JCC_REL8_BASE + @intFromEnum(condition);
    written += 1;
    try write_byte(writer, opcode);

    const imm = extractBits(i8, disp);
    written += 1;
    try write_bytes(writer, &imm);

    return written;
}

/// jcc rel32
pub fn rel32(writer: *Writer, condition: Condition, disp: i32) EncodingError!usize {
    var written: usize = 0;

    written += 1;
    try write_byte(writer, JCC_OPCODE.JCC_REL32_ESCAPE);

    const opcode = JCC_OPCODE.JCC_REL32_BASE + @intFromEnum(condition);
    written += 1;
    try write_byte(writer, opcode);

    const imm = extractBits(i32, disp);
    written += 4;
    try write_bytes(writer, &imm);

    return written;
}

/// Backpatch a `jcc rel8` encoded at `op_addr`.
/// `patch_value` is the absolute target address (within `buffer`) to branch to.
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

/// Backpatch a `jcc rel32` encoded at `op_addr`.
/// `patch_value` is the absolute target address (within `buffer`) to branch to.
pub fn patch_rel32(buffer: []u8, op_addr: usize, patch_value: usize) EncodingError!void {
    if (op_addr + 6 > buffer.len) {
        return EncodingError.InvalidPatchAddress;
    }

    const next_ip = op_addr + 6;
    const delta: i64 = @as(i64, @intCast(patch_value)) - @as(i64, @intCast(next_ip));
    const disp: i32 = std.math.cast(i32, delta) orelse return EncodingError.InvalidDisplacement;
    const bytes = extractBits(i32, disp);
    @memcpy(buffer[op_addr + 2 .. op_addr + 6], bytes[0..]);
}
