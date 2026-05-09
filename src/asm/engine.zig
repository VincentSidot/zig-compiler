//! Tiny assembly engine for Intel x86-64 architecture.

const std = @import("std");

const ir = @import("ir.zig");
const op_file = @import("op.zig");
pub const CallTarget = op_file.CallTarget;
pub const Condition = op_file.Condition;
pub const JccTarget = op_file.JccTarget;
pub const JumpTarget = op_file.JumpTarget;
pub const Arg = op_file.Arg;
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

pub const Engine = @This();

allocator: std.mem.Allocator,
writer_alloc: std.Io.Writer.Allocating,
written: usize = 0,

labels: std.ArrayList(branch_helper.LabelInfo) = .empty,
fixups: std.ArrayList(branch_helper.Fixup) = .empty,
ops: std.ArrayList(ir.Op) = .empty,

pub const Label = op_file.Label;
pub const RetKind = ret_helper.RetKind;

pub fn init(allocator: std.mem.Allocator) Engine {
    return .{
        .allocator = allocator,
        .writer_alloc = std.Io.Writer.Allocating.init(allocator),
    };
}

pub fn deinit(self: *Engine) void {
    self.writer_alloc.deinit();
    self.labels.deinit(self.allocator);
    self.fixups.deinit(self.allocator);
    self.ops.deinit(self.allocator);
}

pub fn writer(self: *Engine) *std.Io.Writer {
    return &self.writer_alloc.writer;
}

pub fn bytes(self: *Engine) []const u8 {
    return self.writer_alloc.written();
}

pub fn label(self: *Engine) !Label {
    const index = self.labels.items.len;
    try self.labels.append(self.allocator, .{});
    return .{ .index = index };
}

pub fn bind(self: *Engine, label_: Label) !void {
    if (label_.index >= self.labels.items.len) return error.InvalidLabel;
    if (self.labels.items[label_.index].bound) return error.LabelAlreadyBound;

    self.labels.items[label_.index].bound = true;
    try self.ops.append(self.allocator, .{ .bind = label_ });
}

/// Resolves all fixups and returns the emitted machine code.
/// Note: The engine will be deinitialized after this call, so it should not be used afterwards.
pub fn finalize(self: *Engine) ![]u8 {
    for (self.ops.items) |op| {
        try self.emit(op);
    }

    const emitted = try self.writer_alloc.toOwnedSlice();
    try branch_helper.resolve_fixups(emitted, self.fixups.items, self.labels.items);
    self.deinit();

    return emitted;
}

fn emit(self: *Engine, op: ir.Op) !void {
    switch (op) {
        .bind => |label_| {
            if (label_.index >= self.labels.items.len) return error.InvalidLabel;
            self.labels.items[label_.index].offset = self.written;
        },
        .mov => |x| try mov_helper.mov(self.writer(), &self.written, x.dst, x.src),
        .add => |x| try add_helper.add(self.writer(), &self.written, x.dst, x.src),
        .sub => |x| try sub_helper.sub(self.writer(), &self.written, x.dst, x.src),
        .cmp => |x| try cmp_helper.cmp(self.writer(), &self.written, x.dst, x.src),
        .lea => |x| try lea_helper.lea(self.writer(), &self.written, x.dst, x.src),
        .@"and" => |x| try bit_helper.@"and"(self.writer(), &self.written, x.dst, x.src),
        .@"or" => |x| try bit_helper.@"or"(self.writer(), &self.written, x.dst, x.src),
        .xor => |x| try xor_helper.xor(self.writer(), &self.written, x.dst, x.src),
        .@"test" => |x| try bit_helper.@"test"(self.writer(), &self.written, x.dst, x.src),
        .push => |operand| try single_helper.push(self.writer(), &self.written, operand),
        .pop => |operand| try single_helper.pop(self.writer(), &self.written, operand),
        .inc => |operand| try single_helper.inc(self.writer(), &self.written, operand),
        .dec => |operand| try single_helper.dec(self.writer(), &self.written, operand),
        .jmp => |target| try branch_helper.jmp(self.writer(), &self.written, self.allocator, &self.fixups, target),
        .jcc => |x| try branch_helper.jcc(self.writer(), &self.written, self.allocator, &self.fixups, x.condition, x.target),
        .call => |target| try branch_helper.call(self.writer(), &self.written, self.allocator, &self.fixups, target),
        .ret => try ret_helper.ret(self.writer(), &self.written, .Default),
        .syscall => try syscall_helper.syscall(self.writer(), &self.written),
    }
}

fn appendOp(self: *Engine, op: ir.Op) void {
    self.ops.append(self.allocator, op) catch @panic("asm engine: out of memory while recording instruction");
}

// Operations

pub fn mov(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .mov = .{ .dst = dst, .src = src } });
}

pub fn add(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .add = .{ .dst = dst, .src = src } });
}

pub fn sub(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .sub = .{ .dst = dst, .src = src } });
}

pub fn cmp(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .cmp = .{ .dst = dst, .src = src } });
}

pub fn lea(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .lea = .{ .dst = dst, .src = src } });
}

pub fn @"and"(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .@"and" = .{ .dst = dst, .src = src } });
}

pub fn @"or"(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .@"or" = .{ .dst = dst, .src = src } });
}

pub fn xor(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .xor = .{ .dst = dst, .src = src } });
}

pub fn @"test"(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .@"test" = .{ .dst = dst, .src = src } });
}

pub fn push(self: *Engine, operand: Arg) void {
    self.appendOp(.{ .push = operand });
}

pub fn pop(self: *Engine, operand: Arg) void {
    self.appendOp(.{ .pop = operand });
}

pub fn inc(self: *Engine, operand: Arg) void {
    self.appendOp(.{ .inc = operand });
}

pub fn dec(self: *Engine, operand: Arg) void {
    self.appendOp(.{ .dec = operand });
}

pub fn jmp(self: *Engine, target: JumpTarget) void {
    self.appendOp(.{ .jmp = target });
}

pub fn jcc(self: *Engine, condition: Condition, target: JccTarget) void {
    self.appendOp(.{ .jcc = .{ .condition = condition, .target = target } });
}

pub fn call(self: *Engine, target: CallTarget) void {
    self.appendOp(.{ .call = target });
}

pub fn ret(self: *Engine) void {
    self.appendOp(.ret);
}

pub fn syscall(self: *Engine) void {
    self.appendOp(.syscall);
}
