//! Encoder module for Jcc instruction forms.
//! This is built from https://www.felixcloutier.com/x86/jcc

const std = @import("std");

const error_file = @import("../error.zig");
const EncodingError = error_file.EncodingError;

const helper_file = @import("../helper.zig");
const extractBits = helper_file.extractBits;

const Writer = std.io.Writer;

pub const Condition = enum(u4) {
    o = 0x0,
    no = 0x1,
    b = 0x2, // c, nae
    ae = 0x3, // nb, nc
    e = 0x4, // z
    ne = 0x5, // nz
    be = 0x6, // na
    a = 0x7, // nbe
    s = 0x8,
    ns = 0x9,
    p = 0xA, // pe
    np = 0xB, // po
    l = 0xC, // nge
    ge = 0xD, // nl
    le = 0xE, // ng
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

pub fn jz_rel8(writer: *Writer, disp: i8) EncodingError!usize {
    return rel8(writer, .e, disp);
}
pub fn jnz_rel8(writer: *Writer, disp: i8) EncodingError!usize {
    return rel8(writer, .ne, disp);
}
pub fn jl_rel8(writer: *Writer, disp: i8) EncodingError!usize {
    return rel8(writer, .l, disp);
}
pub fn jg_rel8(writer: *Writer, disp: i8) EncodingError!usize {
    return rel8(writer, .g, disp);
}
pub fn jb_rel8(writer: *Writer, disp: i8) EncodingError!usize {
    return rel8(writer, .b, disp);
}
pub fn ja_rel8(writer: *Writer, disp: i8) EncodingError!usize {
    return rel8(writer, .a, disp);
}

pub fn jz_rel32(writer: *Writer, disp: i32) EncodingError!usize {
    return rel32(writer, .e, disp);
}
pub fn jnz_rel32(writer: *Writer, disp: i32) EncodingError!usize {
    return rel32(writer, .ne, disp);
}
pub fn jl_rel32(writer: *Writer, disp: i32) EncodingError!usize {
    return rel32(writer, .l, disp);
}
pub fn jg_rel32(writer: *Writer, disp: i32) EncodingError!usize {
    return rel32(writer, .g, disp);
}
pub fn jle_rel32(writer: *Writer, disp: i32) EncodingError!usize {
    return rel32(writer, .le, disp);
}
pub fn jge_rel32(writer: *Writer, disp: i32) EncodingError!usize {
    return rel32(writer, .ge, disp);
}
