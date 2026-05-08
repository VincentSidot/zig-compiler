const std = @import("std");

const op_file = @import("../op.zig");
const Arg = op_file.Arg;

const encoder = @import("../../encoder/lib.zig");
const opcode = encoder.opcode;

pub fn mov(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    if (dst.is_register()) {
        if (src.is_register()) return movRegReg(writer, written, dst, src);
        if (src.is_immediate()) return movRegImm(writer, written, dst, src);
        if (src.is_memory()) return movRegMem(writer, written, dst, src);
    }

    if (dst.is_memory()) {
        if (src.is_register()) return movMemReg(writer, written, dst, src);
        if (src.is_immediate()) return movMemImm(writer, written, dst, src);
    }

    return error.InvalidOperand;
}

fn movRegReg(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;
    if (kind != (src.register() orelse return error.InvalidOperand)) return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.mov.r8_r8(writer, dst.reg8() orelse unreachable, src.reg8() orelse unreachable),
        .Reg16 => try opcode.mov.r16_r16(writer, dst.reg16() orelse unreachable, src.reg16() orelse unreachable),
        .Reg32 => try opcode.mov.r32_r32(writer, dst.reg32() orelse unreachable, src.reg32() orelse unreachable),
        .Reg64 => try opcode.mov.r64_r64(writer, dst.reg64() orelse unreachable, src.reg64() orelse unreachable),
    };
}

fn movRegImm(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.mov.r8_imm8(writer, dst.reg8() orelse unreachable, try src.imm8() orelse unreachable),
        .Reg16 => try opcode.mov.r16_imm16(writer, dst.reg16() orelse unreachable, try src.imm16() orelse unreachable),
        .Reg32 => try opcode.mov.r32_imm32(writer, dst.reg32() orelse unreachable, try src.imm32() orelse unreachable),
        .Reg64 => try opcode.mov.r64_imm64_auto(writer, dst.reg64() orelse unreachable, try src.imm64() orelse unreachable),
    };
}

fn movRegMem(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.mov.r8_rm8(writer, dst.reg8() orelse unreachable, try src.mem8() orelse return error.InvalidOperand),
        .Reg16 => try opcode.mov.r16_rm16(writer, dst.reg16() orelse unreachable, try src.mem16() orelse return error.InvalidOperand),
        .Reg32 => try opcode.mov.r32_rm32(writer, dst.reg32() orelse unreachable, try src.mem32() orelse return error.InvalidOperand),
        .Reg64 => try opcode.mov.r64_rm64(writer, dst.reg64() orelse unreachable, try src.mem64() orelse return error.InvalidOperand),
    };
}

fn movMemReg(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = src.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.mov.rm8_r8(writer, try dst.mem8() orelse return error.InvalidOperand, src.reg8() orelse unreachable),
        .Reg16 => try opcode.mov.rm16_r16(writer, try dst.mem16() orelse return error.InvalidOperand, src.reg16() orelse unreachable),
        .Reg32 => try opcode.mov.rm32_r32(writer, try dst.mem32() orelse return error.InvalidOperand, src.reg32() orelse unreachable),
        .Reg64 => try opcode.mov.rm64_r64(writer, try dst.mem64() orelse return error.InvalidOperand, src.reg64() orelse unreachable),
    };
}

fn movMemImm(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const mem = switch (dst) {
        .mem => |mem| mem,
        else => return error.InvalidOperand,
    };

    written.* += switch (mem.size) {
        .byte => try opcode.mov.rm8_imm8(writer, try dst.mem8() orelse unreachable, try src.imm8() orelse unreachable),
        .word => try opcode.mov.rm16_imm16(writer, try dst.mem16() orelse unreachable, try src.imm16() orelse unreachable),
        .dword => try opcode.mov.rm32_imm32(writer, try dst.mem32() orelse unreachable, try src.imm32() orelse unreachable),
        .qword => try opcode.mov.rm64_imm32(writer, try dst.mem64() orelse unreachable, try src.imm32() orelse unreachable),
    };
}
