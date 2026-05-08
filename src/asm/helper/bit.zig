const std = @import("std");

const op_file = @import("../op.zig");
const Arg = op_file.Arg;

const encoder = @import("../../encoder/lib.zig");
const opcode = encoder.opcode;

pub fn @"and"(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    return bitOp("and", opcode.bitand, writer, written, dst, src);
}

pub fn @"or"(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    return bitOp("or", opcode.bitor, writer, written, dst, src);
}

pub fn @"test"(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    if (dst.is_register()) {
        if (src.is_register()) return testRegReg(writer, written, dst, src);
        if (src.is_immediate()) return testRegImm(writer, written, dst, src);
    }

    if (dst.is_memory()) {
        if (src.is_register()) return testMemReg(writer, written, dst, src);
        if (src.is_immediate()) return testMemImm(writer, written, dst, src);
    }

    return invalidOperand("test", dst, src);
}

fn bitOp(
    comptime name: []const u8,
    comptime op: type,
    writer: *std.Io.Writer,
    written: *usize,
    dst: Arg,
    src: Arg,
) !void {
    if (dst.is_register()) {
        if (src.is_register()) return bitRegReg(op, writer, written, dst, src);
        if (src.is_immediate()) return bitRegImm(op, writer, written, dst, src);
        if (src.is_memory()) return bitRegMem(op, writer, written, dst, src);
    }

    if (dst.is_memory()) {
        if (src.is_register()) return bitMemReg(op, writer, written, dst, src);
        if (src.is_immediate()) return bitMemImm(op, writer, written, dst, src);
    }

    return invalidOperand(name, dst, src);
}

fn bitRegReg(comptime op: type, writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;
    if (kind != (src.register() orelse return error.InvalidOperand)) return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try op.r8_rm8(writer, dst.reg8() orelse unreachable, .{ .reg = src.reg8() orelse unreachable }),
        .Reg16 => try op.r16_rm16(writer, dst.reg16() orelse unreachable, .{ .reg = src.reg16() orelse unreachable }),
        .Reg32 => try op.r32_rm32(writer, dst.reg32() orelse unreachable, .{ .reg = src.reg32() orelse unreachable }),
        .Reg64 => try op.r64_rm64(writer, dst.reg64() orelse unreachable, .{ .reg = src.reg64() orelse unreachable }),
    };
}

fn bitRegImm(comptime op: type, writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try op.r8_imm8(writer, dst.reg8() orelse unreachable, try src.imm8() orelse unreachable),
        .Reg16 => try op.r16_imm16(writer, dst.reg16() orelse unreachable, try src.imm16() orelse unreachable),
        .Reg32 => try op.r32_imm32(writer, dst.reg32() orelse unreachable, try src.imm32() orelse unreachable),
        .Reg64 => try op.r64_imm32(writer, dst.reg64() orelse unreachable, try src.imm32() orelse unreachable),
    };
}

fn bitRegMem(comptime op: type, writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try op.r8_rm8(writer, dst.reg8() orelse unreachable, try src.mem8() orelse return error.InvalidOperand),
        .Reg16 => try op.r16_rm16(writer, dst.reg16() orelse unreachable, try src.mem16() orelse return error.InvalidOperand),
        .Reg32 => try op.r32_rm32(writer, dst.reg32() orelse unreachable, try src.mem32() orelse return error.InvalidOperand),
        .Reg64 => try op.r64_rm64(writer, dst.reg64() orelse unreachable, try src.mem64() orelse return error.InvalidOperand),
    };
}

fn bitMemReg(comptime op: type, writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = src.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try op.rm8_r8(writer, try dst.mem8() orelse return error.InvalidOperand, src.reg8() orelse unreachable),
        .Reg16 => try op.rm16_r16(writer, try dst.mem16() orelse return error.InvalidOperand, src.reg16() orelse unreachable),
        .Reg32 => try op.rm32_r32(writer, try dst.mem32() orelse return error.InvalidOperand, src.reg32() orelse unreachable),
        .Reg64 => try op.rm64_r64(writer, try dst.mem64() orelse return error.InvalidOperand, src.reg64() orelse unreachable),
    };
}

fn bitMemImm(comptime op: type, writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const mem = switch (dst) {
        .mem => |mem| mem,
        else => return error.InvalidOperand,
    };

    written.* += switch (mem.size) {
        .byte => try op.rm8_imm8(writer, try dst.mem8() orelse unreachable, try src.imm8() orelse unreachable),
        .word => try op.rm16_imm16(writer, try dst.mem16() orelse unreachable, try src.imm16() orelse unreachable),
        .dword => try op.rm32_imm32(writer, try dst.mem32() orelse unreachable, try src.imm32() orelse unreachable),
        .qword => try op.rm64_imm32(writer, try dst.mem64() orelse unreachable, try src.imm32() orelse unreachable),
    };
}

fn testRegReg(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;
    if (kind != (src.register() orelse return error.InvalidOperand)) return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.test_op.rm8_r8(writer, .{ .reg = dst.reg8() orelse unreachable }, src.reg8() orelse unreachable),
        .Reg16 => try opcode.test_op.rm16_r16(writer, .{ .reg = dst.reg16() orelse unreachable }, src.reg16() orelse unreachable),
        .Reg32 => try opcode.test_op.rm32_r32(writer, .{ .reg = dst.reg32() orelse unreachable }, src.reg32() orelse unreachable),
        .Reg64 => try opcode.test_op.rm64_r64(writer, .{ .reg = dst.reg64() orelse unreachable }, src.reg64() orelse unreachable),
    };
}

fn testRegImm(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.test_op.r8_imm8(writer, dst.reg8() orelse unreachable, try src.imm8() orelse unreachable),
        .Reg16 => try opcode.test_op.r16_imm16(writer, dst.reg16() orelse unreachable, try src.imm16() orelse unreachable),
        .Reg32 => try opcode.test_op.r32_imm32(writer, dst.reg32() orelse unreachable, try src.imm32() orelse unreachable),
        .Reg64 => try opcode.test_op.r64_imm32(writer, dst.reg64() orelse unreachable, try src.imm32() orelse unreachable),
    };
}

fn testMemReg(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = src.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.test_op.rm8_r8(writer, try dst.mem8() orelse return error.InvalidOperand, src.reg8() orelse unreachable),
        .Reg16 => try opcode.test_op.rm16_r16(writer, try dst.mem16() orelse return error.InvalidOperand, src.reg16() orelse unreachable),
        .Reg32 => try opcode.test_op.rm32_r32(writer, try dst.mem32() orelse return error.InvalidOperand, src.reg32() orelse unreachable),
        .Reg64 => try opcode.test_op.rm64_r64(writer, try dst.mem64() orelse return error.InvalidOperand, src.reg64() orelse unreachable),
    };
}

fn testMemImm(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const mem = switch (dst) {
        .mem => |mem| mem,
        else => return error.InvalidOperand,
    };

    written.* += switch (mem.size) {
        .byte => try opcode.test_op.rm8_imm8(writer, try dst.mem8() orelse unreachable, try src.imm8() orelse unreachable),
        .word => try opcode.test_op.rm16_imm16(writer, try dst.mem16() orelse unreachable, try src.imm16() orelse unreachable),
        .dword => try opcode.test_op.rm32_imm32(writer, try dst.mem32() orelse unreachable, try src.imm32() orelse unreachable),
        .qword => try opcode.test_op.rm64_imm32(writer, try dst.mem64() orelse unreachable, try src.imm32() orelse unreachable),
    };
}

fn invalidOperand(comptime name: []const u8, dst: Arg, src: Arg) error{InvalidOperand} {
    std.log.debug("asm {s}: invalid operands dst={any}, src={any}", .{ name, dst, src });
    return error.InvalidOperand;
}
