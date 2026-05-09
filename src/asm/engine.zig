//! Tiny assembly engine for Intel x86-64 architecture.

const std = @import("std");
const log = std.log;

// IR module
const ir = @import("ir.zig");

// Layout module
const layout = @import("layout.zig");
const lower = @import("lower.zig");

// Operations module
const op_file = @import("op.zig");
pub const CallTarget = op_file.CallTarget;
pub const Condition = op_file.Condition;
pub const JccTarget = op_file.JccTarget;
pub const JumpTarget = op_file.JumpTarget;
pub const Arg = op_file.Arg;

const branch_helper = @import("helper/branch.zig");
const ret_helper = @import("helper/ret.zig");

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
/// Note: The engine will be deinitialized after this call, so it should be reinitialized to emit more code.
pub fn finalize(self: *Engine) ![]u8 {
    const resolved = try layout.resolveOps(self.allocator, self.ops.items);
    defer self.allocator.free(resolved);

    const passes = try layout.relaxLayout(self.allocator, resolved, self.labels.items);

    for (resolved) |resolved_op| {
        try self.emit(resolved_op);
    }

    const emitted = try self.writer_alloc.toOwnedSlice();
    try branch_helper.resolve_fixups(emitted, self.fixups.items, self.labels.items);
    self.deinit();

    log.debug("emitted {d} bytes in {d} passes", .{ emitted.len, passes });

    return emitted;
}

fn emit(self: *Engine, resolved_op: layout.ResolvedOp) !void {
    try lower.emit(resolved_op.op, resolved_op.branch_encoding, self.writer(), &self.written, .{
        .allocator = self.allocator,
        .fixups = &self.fixups,
    });
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
