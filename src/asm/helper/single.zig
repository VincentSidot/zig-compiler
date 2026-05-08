const std = @import("std");

const op_file = @import("../op.zig");
const Arg = op_file.Arg;

const encoder = @import("../../encoder/lib.zig");
const opcode = encoder.opcode;

pub fn push(writer: *std.Io.Writer, written: *usize, operand: Arg) !void {
    if (operand.is_register()) {
        const kind = operand.register() orelse return error.InvalidOperand;
        written.* += switch (kind) {
            .Reg16 => try opcode.push.r16(writer, operand.reg16() orelse unreachable),
            .Reg32 => try opcode.push.r32(writer, operand.reg32() orelse unreachable),
            .Reg64 => try opcode.push.r64(writer, operand.reg64() orelse unreachable),
            .Reg8 => return error.InvalidOperand,
        };
        return;
    }

    if (operand.is_memory()) {
        const mem = switch (operand) {
            .mem => |mem| mem,
            else => unreachable,
        };
        written.* += switch (mem.size) {
            .word => try opcode.push.rm16(writer, try operand.mem16() orelse unreachable),
            .dword => try opcode.push.rm32(writer, try operand.mem32() orelse unreachable),
            .qword => try opcode.push.rm64(writer, try operand.mem64() orelse unreachable),
            .byte => return error.InvalidOperand,
        };
        return;
    }

    if (operand.is_immediate()) {
        const value = switch (operand) {
            .imm => |value| value,
            else => unreachable,
        };

        if (std.math.cast(i8, value)) |imm| {
            written.* += try opcode.push.imm8(writer, imm);
            return;
        }

        written.* += try opcode.push.imm32(writer, try operand.imm32() orelse return error.InvalidOperand);
        return;
    }

    return error.InvalidOperand;
}

pub fn pop(writer: *std.Io.Writer, written: *usize, operand: Arg) !void {
    if (operand.is_register()) {
        const kind = operand.register() orelse return error.InvalidOperand;
        written.* += switch (kind) {
            .Reg16 => try opcode.pop.r16(writer, operand.reg16() orelse unreachable),
            .Reg32 => try opcode.pop.r32(writer, operand.reg32() orelse unreachable),
            .Reg64 => try opcode.pop.r64(writer, operand.reg64() orelse unreachable),
            .Reg8 => return error.InvalidOperand,
        };
        return;
    }

    if (operand.is_memory()) {
        const mem = switch (operand) {
            .mem => |mem| mem,
            else => unreachable,
        };
        written.* += switch (mem.size) {
            .word => try opcode.pop.rm16(writer, try operand.mem16() orelse unreachable),
            .dword => try opcode.pop.rm32(writer, try operand.mem32() orelse unreachable),
            .qword => try opcode.pop.rm64(writer, try operand.mem64() orelse unreachable),
            .byte => return error.InvalidOperand,
        };
        return;
    }

    return error.InvalidOperand;
}

pub fn inc(writer: *std.Io.Writer, written: *usize, operand: Arg) !void {
    try incDec(.inc, writer, written, operand);
}

pub fn dec(writer: *std.Io.Writer, written: *usize, operand: Arg) !void {
    try incDec(.dec, writer, written, operand);
}

const IncDecOp = enum {
    inc,
    dec,
};

fn incDec(op: IncDecOp, writer: *std.Io.Writer, written: *usize, operand: Arg) !void {
    if (operand.is_register()) {
        const kind = operand.register() orelse return error.InvalidOperand;
        written.* += switch (kind) {
            .Reg8 => switch (op) {
                .inc => try opcode.inc.rm8(writer, .{ .reg = operand.reg8() orelse unreachable }),
                .dec => try opcode.dec.rm8(writer, .{ .reg = operand.reg8() orelse unreachable }),
            },
            .Reg16 => switch (op) {
                .inc => try opcode.inc.rm16(writer, .{ .reg = operand.reg16() orelse unreachable }),
                .dec => try opcode.dec.rm16(writer, .{ .reg = operand.reg16() orelse unreachable }),
            },
            .Reg32 => switch (op) {
                .inc => try opcode.inc.rm32(writer, .{ .reg = operand.reg32() orelse unreachable }),
                .dec => try opcode.dec.rm32(writer, .{ .reg = operand.reg32() orelse unreachable }),
            },
            .Reg64 => switch (op) {
                .inc => try opcode.inc.rm64(writer, .{ .reg = operand.reg64() orelse unreachable }),
                .dec => try opcode.dec.rm64(writer, .{ .reg = operand.reg64() orelse unreachable }),
            },
        };
        return;
    }

    if (operand.is_memory()) {
        const mem = switch (operand) {
            .mem => |mem| mem,
            else => unreachable,
        };
        written.* += switch (mem.size) {
            .byte => switch (op) {
                .inc => try opcode.inc.rm8(writer, try operand.mem8() orelse unreachable),
                .dec => try opcode.dec.rm8(writer, try operand.mem8() orelse unreachable),
            },
            .word => switch (op) {
                .inc => try opcode.inc.rm16(writer, try operand.mem16() orelse unreachable),
                .dec => try opcode.dec.rm16(writer, try operand.mem16() orelse unreachable),
            },
            .dword => switch (op) {
                .inc => try opcode.inc.rm32(writer, try operand.mem32() orelse unreachable),
                .dec => try opcode.dec.rm32(writer, try operand.mem32() orelse unreachable),
            },
            .qword => switch (op) {
                .inc => try opcode.inc.rm64(writer, try operand.mem64() orelse unreachable),
                .dec => try opcode.dec.rm64(writer, try operand.mem64() orelse unreachable),
            },
        };
        return;
    }

    return error.InvalidOperand;
}
