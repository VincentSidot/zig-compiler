const std = @import("std");

const ir = @import("ir.zig");
const add_helper = @import("helper/add.zig");
const bit_helper = @import("helper/bit.zig");
const branch_helper = @import("helper/branch.zig");
const cmp_helper = @import("helper/cmp.zig");
const lea_helper = @import("helper/lea.zig");
const mov_helper = @import("helper/mov.zig");
const ret_helper = @import("helper/ret.zig");
const single_helper = @import("helper/single.zig");
const sub_helper = @import("helper/sub.zig");
const syscall_helper = @import("helper/syscall.zig");
const xor_helper = @import("helper/xor.zig");

/// Shared lowering state used during sizing and byte emission.
pub const Context = struct {
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(branch_helper.Fixup),
};

/// Lowers an IR instruction using its default branch encoding.
pub fn op(
    inst: ir.Op,
    writer: ?*std.Io.Writer,
    written: *usize,
    ctx: Context,
) !void {
    try opWithEncoding(inst, null, writer, written, ctx);
}

/// Returns the encoded size of an IR instruction for the selected branch encoding.
pub fn sizeOf(
    allocator: std.mem.Allocator,
    inst: ir.Op,
    branch_encoding: ?ir.BranchEncoding,
) !usize {
    var written: usize = 0;
    var fixups = std.ArrayList(branch_helper.Fixup).empty;
    defer fixups.deinit(allocator);

    try opWithEncoding(inst, branch_encoding, null, &written, .{
        .allocator = allocator,
        .fixups = &fixups,
    });

    return written;
}

/// Emits one IR instruction to `writer` using the selected branch encoding.
pub fn emit(
    inst: ir.Op,
    branch_encoding: ?ir.BranchEncoding,
    writer: *std.Io.Writer,
    written: *usize,
    ctx: Context,
) !void {
    try opWithEncoding(inst, branch_encoding, writer, written, ctx);
}

/// Lowers an IR instruction using an explicit branch encoding override.
pub fn opWithEncoding(
    inst: ir.Op,
    branch_encoding: ?ir.BranchEncoding,
    writer: ?*std.Io.Writer,
    written: *usize,
    ctx: Context,
) !void {
    switch (inst) {
        .bind => {},
        .mov => |x| try mov_helper.mov(writer, written, x.dst, x.src),
        .add => |x| try add_helper.add(writer, written, x.dst, x.src),
        .sub => |x| try sub_helper.sub(writer, written, x.dst, x.src),
        .cmp => |x| try cmp_helper.cmp(writer, written, x.dst, x.src),
        .lea => |x| try lea_helper.lea(writer, written, x.dst, x.src),
        .@"and" => |x| try bit_helper.@"and"(writer, written, x.dst, x.src),
        .@"or" => |x| try bit_helper.@"or"(writer, written, x.dst, x.src),
        .xor => |x| try xor_helper.xor(writer, written, x.dst, x.src),
        .@"test" => |x| try bit_helper.@"test"(writer, written, x.dst, x.src),
        .push => |operand| try single_helper.push(writer, written, operand),
        .pop => |operand| try single_helper.pop(writer, written, operand),
        .inc => |operand| try single_helper.inc(writer, written, operand),
        .dec => |operand| try single_helper.dec(writer, written, operand),
        .jmp => |target| try branch_helper.jmp(writer, written, ctx.allocator, ctx.fixups, target, branch_encoding),
        .jcc => |x| try branch_helper.jcc(writer, written, ctx.allocator, ctx.fixups, x.condition, x.target, branch_encoding),
        .call => |target| try branch_helper.call(writer, written, ctx.allocator, ctx.fixups, target),
        .ret => try ret_helper.ret(writer, written, .Default),
        .syscall => try syscall_helper.syscall(writer, written),
    }
}
