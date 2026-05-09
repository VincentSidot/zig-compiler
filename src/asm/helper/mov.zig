const std = @import("std");

const op_file = @import("../op.zig");
const Arg = op_file.Arg;
const lower = @import("../lower.zig");

const encoder = @import("../../encoder/lib.zig");
const opcode = encoder.opcode;

pub fn mov(
    writer: ?*std.Io.Writer,
    written: *usize,
    dst: Arg,
    src: Arg,
    allocator: std.mem.Allocator,
    symbol_patches: ?*std.ArrayList(lower.SymbolPatch),
) !void {
    if (dst.is_register()) {
        if (src.is_register()) return movRegReg(writer, written, dst, src);
        if (src.is_symbol()) return movRegSym(writer, written, dst, src, allocator, symbol_patches);
        if (src.is_immediate()) return movRegImm(writer, written, dst, src);
        if (src.is_memory()) return movRegMem(writer, written, dst, src);
    }

    if (dst.is_memory()) {
        if (src.is_register()) return movMemReg(writer, written, dst, src);
        if (src.is_immediate()) return movMemImm(writer, written, dst, src);
    }

    return error.InvalidOperand;
}

fn movRegSym(
    writer: ?*std.Io.Writer,
    written: *usize,
    dst: Arg,
    src: Arg,
    allocator: std.mem.Allocator,
    symbol_patches: ?*std.ArrayList(lower.SymbolPatch),
) !void {
    const sym = switch (src) {
        .sym => |sym| sym,
        else => return error.InvalidOperand,
    };
    if (sym.kind != .abs64) return error.InvalidOperand;

    const reg = dst.as_reg64() orelse return error.InvalidOperand;
    const patch_offset = written.* + 2;
    written.* += try opcode.mov.r64_imm64(writer, reg, 0);

    if (symbol_patches) |patches| {
        try patches.append(allocator, .{
            .symbol = sym.id,
            .offset = patch_offset,
            .kind = .abs64,
        });
    }
}

fn movRegReg(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;
    if (kind != (src.register() orelse return error.InvalidOperand)) return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.mov.r8_r8(writer, dst.as_reg8() orelse unreachable, src.as_reg8() orelse unreachable),
        .Reg16 => try opcode.mov.r16_r16(writer, dst.as_reg16() orelse unreachable, src.as_reg16() orelse unreachable),
        .Reg32 => try opcode.mov.r32_r32(writer, dst.as_reg32() orelse unreachable, src.as_reg32() orelse unreachable),
        .Reg64 => try opcode.mov.r64_r64(writer, dst.as_reg64() orelse unreachable, src.as_reg64() orelse unreachable),
    };
}

fn movRegImm(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.mov.r8_imm8(writer, dst.as_reg8() orelse unreachable, try src.as_imm8() orelse unreachable),
        .Reg16 => try opcode.mov.r16_imm16(writer, dst.as_reg16() orelse unreachable, try src.as_imm16() orelse unreachable),
        .Reg32 => try opcode.mov.r32_imm32(writer, dst.as_reg32() orelse unreachable, try src.as_imm32() orelse unreachable),
        .Reg64 => try opcode.mov.r64_imm64_auto(writer, dst.as_reg64() orelse unreachable, try src.as_imm64() orelse unreachable),
    };
}

fn movRegMem(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = dst.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.mov.r8_rm8(writer, dst.as_reg8() orelse unreachable, try src.as_mem8() orelse return error.InvalidOperand),
        .Reg16 => try opcode.mov.r16_rm16(writer, dst.as_reg16() orelse unreachable, try src.as_mem16() orelse return error.InvalidOperand),
        .Reg32 => try opcode.mov.r32_rm32(writer, dst.as_reg32() orelse unreachable, try src.as_mem32() orelse return error.InvalidOperand),
        .Reg64 => try opcode.mov.r64_rm64(writer, dst.as_reg64() orelse unreachable, try src.as_mem64() orelse return error.InvalidOperand),
    };
}

fn movMemReg(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const kind = src.register() orelse return error.InvalidOperand;

    written.* += switch (kind) {
        .Reg8 => try opcode.mov.rm8_r8(writer, try dst.as_mem8() orelse return error.InvalidOperand, src.as_reg8() orelse unreachable),
        .Reg16 => try opcode.mov.rm16_r16(writer, try dst.as_mem16() orelse return error.InvalidOperand, src.as_reg16() orelse unreachable),
        .Reg32 => try opcode.mov.rm32_r32(writer, try dst.as_mem32() orelse return error.InvalidOperand, src.as_reg32() orelse unreachable),
        .Reg64 => try opcode.mov.rm64_r64(writer, try dst.as_mem64() orelse return error.InvalidOperand, src.as_reg64() orelse unreachable),
    };
}

fn movMemImm(writer: ?*std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    const mem = switch (dst) {
        .mem => |mem| mem,
        else => return error.InvalidOperand,
    };

    written.* += switch (mem.size) {
        .byte => try opcode.mov.rm8_imm8(writer, try dst.as_mem8() orelse unreachable, try src.as_imm8() orelse unreachable),
        .word => try opcode.mov.rm16_imm16(writer, try dst.as_mem16() orelse unreachable, try src.as_imm16() orelse unreachable),
        .dword => try opcode.mov.rm32_imm32(writer, try dst.as_mem32() orelse unreachable, try src.as_imm32() orelse unreachable),
        .qword => try opcode.mov.rm64_imm32(writer, try dst.as_mem64() orelse unreachable, try src.as_imm32() orelse unreachable),
    };
}
