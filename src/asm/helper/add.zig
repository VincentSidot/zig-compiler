const std = @import("std");

const op_file = @import("../op.zig");
const Arg = op_file.Arg;

const encoder = @import("../../encoder/lib.zig");
const opcode = encoder.opcode;

pub fn add(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    if (dst.is_register()) {
        if (src.is_register()) return addRegReg(writer, written, dst, src);
        if (src.is_immediate()) return addRegImm(writer, written, dst, src);
        if (src.is_memory()) return addRegMem(writer, written, dst, src);
    }

    if (dst.is_memory()) {
        if (src.is_register()) return addMemReg(writer, written, dst, src);
        if (src.is_immediate()) return addMemImm(writer, written, dst, src);
    }

    return error.InvalidOperand;
}

fn addRegReg(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;
    if (kind != (src.register() orelse return error.InvalidOperand)) return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.add.r8_rm8(writer, dst.reg8() orelse unreachable, .{ .reg = src.reg8() orelse unreachable }),
        .Reg16 => try opcode.add.r16_rm16(writer, dst.reg16() orelse unreachable, .{ .reg = src.reg16() orelse unreachable }),
        .Reg32 => try opcode.add.r32_rm32(writer, dst.reg32() orelse unreachable, .{ .reg = src.reg32() orelse unreachable }),
        .Reg64 => try opcode.add.r64_rm64(writer, dst.reg64() orelse unreachable, .{ .reg = src.reg64() orelse unreachable }),
    };
}

fn addRegImm(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.add.r8_imm8(writer, dst.reg8() orelse unreachable, try src.imm8() orelse unreachable),
        .Reg16 => try opcode.add.r16_imm16(writer, dst.reg16() orelse unreachable, try src.imm16() orelse unreachable),
        .Reg32 => try opcode.add.r32_imm32(writer, dst.reg32() orelse unreachable, try src.imm32() orelse unreachable),
        .Reg64 => try opcode.add.r64_imm32(writer, dst.reg64() orelse unreachable, try src.imm32() orelse unreachable),
    };
}

fn addRegMem(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.add.r8_rm8(writer, dst.reg8() orelse unreachable, try src.mem8() orelse return error.InvalidOperand),
        .Reg16 => try opcode.add.r16_rm16(writer, dst.reg16() orelse unreachable, try src.mem16() orelse return error.InvalidOperand),
        .Reg32 => try opcode.add.r32_rm32(writer, dst.reg32() orelse unreachable, try src.mem32() orelse return error.InvalidOperand),
        .Reg64 => try opcode.add.r64_rm64(writer, dst.reg64() orelse unreachable, try src.mem64() orelse return error.InvalidOperand),
    };
}

fn addMemReg(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = src.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.add.rm8_r8(writer, try dst.mem8() orelse return error.InvalidOperand, src.reg8() orelse unreachable),
        .Reg16 => try opcode.add.rm16_r16(writer, try dst.mem16() orelse return error.InvalidOperand, src.reg16() orelse unreachable),
        .Reg32 => try opcode.add.rm32_r32(writer, try dst.mem32() orelse return error.InvalidOperand, src.reg32() orelse unreachable),
        .Reg64 => try opcode.add.rm64_r64(writer, try dst.mem64() orelse return error.InvalidOperand, src.reg64() orelse unreachable),
    };
}

fn addMemImm(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const mem = switch (dst) {
        .mem => |mem| mem,
        else => return error.InvalidOperand,
    };

    written.* += switch (mem.size) {
        .byte => try opcode.add.rm8_imm8(writer, try dst.mem8() orelse unreachable, try src.imm8() orelse unreachable),
        .word => try opcode.add.rm16_imm16(writer, try dst.mem16() orelse unreachable, try src.imm16() orelse unreachable),
        .dword => try opcode.add.rm32_imm32(writer, try dst.mem32() orelse unreachable, try src.imm32() orelse unreachable),
        .qword => try opcode.add.rm64_imm32(writer, try dst.mem64() orelse unreachable, try src.imm32() orelse unreachable),
    };
}
