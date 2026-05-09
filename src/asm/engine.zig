//! Tiny assembly engine for Intel x86-64 architecture.

const std = @import("std");

const op_file = @import("op.zig");
pub const BranchTarget = op_file.BranchTarget;
pub const Condition = op_file.Condition;
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
    if (self.labels.items[label_.index].offset != null) return error.LabelAlreadyBound;

    self.labels.items[label_.index].offset = self.written;
}

/// Resolves all fixups and returns the emitted machine code.
/// Note: The engine will be deinitialized after this call, so it should not be used afterwards.
pub fn finalize(self: *Engine) ![]u8 {
    const emitted = try self.writer_alloc.toOwnedSlice();
    try branch_helper.resolve_fixups(emitted, self.fixups.items, self.labels.items);
    self.deinit();

    return emitted;
}

// Operations

pub fn mov(self: *Engine, dst: Arg, src: Arg) !void {
    try mov_helper.mov(self.writer(), &self.written, dst, src);
}

pub fn add(self: *Engine, dst: Arg, src: Arg) !void {
    try add_helper.add(self.writer(), &self.written, dst, src);
}

pub fn sub(self: *Engine, dst: Arg, src: Arg) !void {
    try sub_helper.sub(self.writer(), &self.written, dst, src);
}

pub fn cmp(self: *Engine, dst: Arg, src: Arg) !void {
    try cmp_helper.cmp(self.writer(), &self.written, dst, src);
}

pub fn lea(self: *Engine, dst: Arg, src: Arg) !void {
    try lea_helper.lea(self.writer(), &self.written, dst, src);
}

pub fn @"and"(self: *Engine, dst: Arg, src: Arg) !void {
    try bit_helper.@"and"(self.writer(), &self.written, dst, src);
}

pub fn @"or"(self: *Engine, dst: Arg, src: Arg) !void {
    try bit_helper.@"or"(self.writer(), &self.written, dst, src);
}

pub fn xor(self: *Engine, dst: Arg, src: Arg) !void {
    try xor_helper.xor(self.writer(), &self.written, dst, src);
}

pub fn @"test"(self: *Engine, dst: Arg, src: Arg) !void {
    try bit_helper.@"test"(self.writer(), &self.written, dst, src);
}

pub fn push(self: *Engine, operand: Arg) !void {
    try single_helper.push(self.writer(), &self.written, operand);
}

pub fn pop(self: *Engine, operand: Arg) !void {
    try single_helper.pop(self.writer(), &self.written, operand);
}

pub fn inc(self: *Engine, operand: Arg) !void {
    try single_helper.inc(self.writer(), &self.written, operand);
}

pub fn dec(self: *Engine, operand: Arg) !void {
    try single_helper.dec(self.writer(), &self.written, operand);
}

pub fn jmp(self: *Engine, target: BranchTarget) !void {
    try branch_helper.jmp(self.writer(), &self.written, self.allocator, &self.fixups, target);
}

pub fn jcc(self: *Engine, condition: Condition, target: BranchTarget) !void {
    try branch_helper.jcc(self.writer(), &self.written, self.allocator, &self.fixups, condition, target);
}

pub fn call(self: *Engine, target: BranchTarget) !void {
    try branch_helper.call(self.writer(), &self.written, self.allocator, &self.fixups, target);
}

pub fn ret(self: *Engine) !void {
    try ret_helper.ret(self.writer(), &self.written, .Default);
}

pub fn syscall(self: *Engine) !void {
    try syscall_helper.syscall(self.writer(), &self.written);
}
