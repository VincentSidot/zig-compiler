const std = @import("std");

const op_file = @import("../op.zig");
const Arg = op_file.Arg;

const encoder = @import("../../encoder/lib.zig");
const opcode = encoder.opcode;

pub fn lea(writer: *std.Io.Writer, written: *usize, dst: Arg, src: Arg) !void {
    if (!dst.is_register() or !src.is_memory()) {
        std.log.debug("asm lea: invalid operands dst={any}, src={any}", .{ dst, src });
        return error.InvalidOperand;
    }

    const kind = dst.register() orelse return error.InvalidOperand;
    written.* += switch (kind) {
        .Reg8 => {
            std.log.debug("asm lea: 8-bit destination is invalid dst={any}", .{dst});
            return error.InvalidOperand;
        },
        .Reg16 => try opcode.lea.r16_m(writer, dst.reg16() orelse unreachable, try src.mem16() orelse return error.InvalidOperand),
        .Reg32 => try opcode.lea.r32_m(writer, dst.reg32() orelse unreachable, try src.mem32() orelse return error.InvalidOperand),
        .Reg64 => try opcode.lea.r64_m(writer, dst.reg64() orelse unreachable, try src.mem64() orelse return error.InvalidOperand),
    };
}
