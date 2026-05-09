const std = @import("std");

const op_file = @import("../op.zig");
const Arg = op_file.Arg;

const encoder = @import("../../encoder/lib.zig");
const opcode = encoder.opcode;

pub fn sub(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    if (dst.is_register()) {
        if (src.is_register()) return subRegReg(writer, written, dst, src);
        if (src.is_immediate()) return subRegImm(writer, written, dst, src);
        if (src.is_memory()) return subRegMem(writer, written, dst, src);
    }

    if (dst.is_memory()) {
        if (src.is_register()) return subMemReg(writer, written, dst, src);
        if (src.is_immediate()) return subMemImm(writer, written, dst, src);
    }

    return error.InvalidOperand;
}

fn subRegReg(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;
    if (kind != (src.register() orelse return error.InvalidOperand)) return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.sub.r8_rm8(writer, dst.as_reg8() orelse unreachable, .{ .reg = src.as_reg8() orelse unreachable }),
        .Reg16 => try opcode.sub.r16_rm16(writer, dst.as_reg16() orelse unreachable, .{ .reg = src.as_reg16() orelse unreachable }),
        .Reg32 => try opcode.sub.r32_rm32(writer, dst.as_reg32() orelse unreachable, .{ .reg = src.as_reg32() orelse unreachable }),
        .Reg64 => try opcode.sub.r64_rm64(writer, dst.as_reg64() orelse unreachable, .{ .reg = src.as_reg64() orelse unreachable }),
    };
}

fn subRegImm(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.sub.r8_imm8(writer, dst.as_reg8() orelse unreachable, try src.as_imm8() orelse unreachable),
        .Reg16 => try opcode.sub.r16_imm16(writer, dst.as_reg16() orelse unreachable, try src.as_imm16() orelse unreachable),
        .Reg32 => try opcode.sub.r32_imm32(writer, dst.as_reg32() orelse unreachable, try src.as_imm32() orelse unreachable),
        .Reg64 => try opcode.sub.r64_imm32(writer, dst.as_reg64() orelse unreachable, try src.as_imm32() orelse unreachable),
    };
}

fn subRegMem(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.sub.r8_rm8(writer, dst.as_reg8() orelse unreachable, try src.as_mem8() orelse return error.InvalidOperand),
        .Reg16 => try opcode.sub.r16_rm16(writer, dst.as_reg16() orelse unreachable, try src.as_mem16() orelse return error.InvalidOperand),
        .Reg32 => try opcode.sub.r32_rm32(writer, dst.as_reg32() orelse unreachable, try src.as_mem32() orelse return error.InvalidOperand),
        .Reg64 => try opcode.sub.r64_rm64(writer, dst.as_reg64() orelse unreachable, try src.as_mem64() orelse return error.InvalidOperand),
    };
}

fn subMemReg(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = src.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.sub.rm8_r8(writer, try dst.as_mem8() orelse return error.InvalidOperand, src.as_reg8() orelse unreachable),
        .Reg16 => try opcode.sub.rm16_r16(writer, try dst.as_mem16() orelse return error.InvalidOperand, src.as_reg16() orelse unreachable),
        .Reg32 => try opcode.sub.rm32_r32(writer, try dst.as_mem32() orelse return error.InvalidOperand, src.as_reg32() orelse unreachable),
        .Reg64 => try opcode.sub.rm64_r64(writer, try dst.as_mem64() orelse return error.InvalidOperand, src.as_reg64() orelse unreachable),
    };
}

fn subMemImm(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const mem = switch (dst) {
        .mem => |mem| mem,
        else => return error.InvalidOperand,
    };

    written.* += switch (mem.size) {
        .byte => try opcode.sub.rm8_imm8(writer, try dst.as_mem8() orelse unreachable, try src.as_imm8() orelse unreachable),
        .word => try opcode.sub.rm16_imm16(writer, try dst.as_mem16() orelse unreachable, try src.as_imm16() orelse unreachable),
        .dword => try opcode.sub.rm32_imm32(writer, try dst.as_mem32() orelse unreachable, try src.as_imm32() orelse unreachable),
        .qword => try opcode.sub.rm64_imm32(writer, try dst.as_mem64() orelse unreachable, try src.as_imm32() orelse unreachable),
    };
}
