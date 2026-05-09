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
pub const Symbol = op_file.Symbol;

const branch_helper = @import("helper/branch.zig");
const ret_helper = @import("helper/ret.zig");

pub const Engine = @This();

allocator: std.mem.Allocator,
writer_alloc: std.Io.Writer.Allocating,
written: usize = 0,
is_finalized: bool = false,
finalized_bytes: ?[]u8 = null,

labels: std.ArrayList(branch_helper.LabelInfo) = .empty,
fixups: std.ArrayList(branch_helper.Fixup) = .empty,
ops: std.ArrayList(ir.Op) = .empty,
symbols: std.ArrayList(SymbolInfo) = .empty,
symbol_patches: std.ArrayList(lower.SymbolPatch) = .empty,

pub const Label = op_file.Label;
pub const RetKind = ret_helper.RetKind;
const SymbolInfo = struct {
    value: ?u64 = null,
};

/// Creates a new engine that records instructions and allocates emitted bytes with `allocator`.
pub fn init(allocator: std.mem.Allocator) Engine {
    return .{
        .allocator = allocator,
        .writer_alloc = std.Io.Writer.Allocating.init(allocator),
    };
}

/// Releases the engine's internal allocations without producing machine code.
pub fn deinit(self: *Engine) void {
    self.writer_alloc.deinit();
    if (self.finalized_bytes) |buffer| self.allocator.free(buffer);
    self.labels.deinit(self.allocator);
    self.fixups.deinit(self.allocator);
    self.ops.deinit(self.allocator);
    self.symbols.deinit(self.allocator);
    self.symbol_patches.deinit(self.allocator);
}

/// Returns the internal writer used during final machine code emission.
pub fn writer(self: *Engine) *std.Io.Writer {
    return &self.writer_alloc.writer;
}

/// Returns the bytes emitted so far.
/// This is mainly intended for tests and only reflects data written before `finalize`.
pub fn bytes(self: *Engine) []const u8 {
    if (self.finalized_bytes) |buffer| return buffer;
    if (self.is_finalized) return &.{};
    return self.writer_alloc.written();
}

/// Returns the finalized machine code bytes.
pub fn bytecode(self: *Engine) []const u8 {
    return self.bytes();
}

/// Allocates a new label handle that can later be bound and used as a branch target.
pub fn label(self: *Engine) !Label {
    const index = self.labels.items.len;
    try self.labels.append(self.allocator, .{});
    return .{ .index = index };
}

/// Allocates a new symbolic address handle that can be patched after finalization.
pub fn symbol(self: *Engine) !Symbol {
    const index = self.symbols.items.len;
    try self.symbols.append(self.allocator, .{});
    return .{ .index = index };
}

/// Records the current position as the definition of `label_`.
pub fn bind(self: *Engine, label_: Label) !void {
    if (label_.index >= self.labels.items.len) return error.InvalidLabel;
    if (self.labels.items[label_.index].bound) return error.LabelAlreadyBound;

    self.labels.items[label_.index].bound = true;
    try self.ops.append(self.allocator, .{ .bind = label_ });
}

/// Finalizes the recorded instructions and keeps the resulting machine code inside the engine.
pub fn finalize(self: *Engine) !void {
    if (self.is_finalized) return error.AlreadyFinalized;

    const resolved = try layout.resolveOps(self.allocator, self.ops.items);
    defer self.allocator.free(resolved);

    const passes = try layout.relaxLayout(self.allocator, resolved, self.labels.items);

    for (resolved) |resolved_op| {
        try self.emit(resolved_op);
    }

    const emitted = try self.writer_alloc.toOwnedSlice();
    try branch_helper.resolve_fixups(emitted, self.fixups.items, self.labels.items);
    self.is_finalized = true;
    self.finalized_bytes = emitted;
    try self.applySymbolValues();

    log.debug("emitted {d} bytes in {d} passes", .{ emitted.len, passes });
}

/// Transfers ownership of the finalized machine code to the caller.
pub fn takeBytes(self: *Engine) ![]u8 {
    if (!self.is_finalized) return error.NotFinalized;
    if (self.finalized_bytes == null) return error.BytesAlreadyTaken;
    const buffer = self.finalized_bytes.?;
    self.finalized_bytes = null;
    return buffer;
}

/// Patches all uses of `sym` in `buffer` with `value`.
pub fn patch(self: *const Engine, buffer: []u8, sym: Symbol, value: u64) !void {
    if (!self.is_finalized) return error.NotFinalized;
    if (sym.index >= self.symbols.items.len) return error.InvalidSymbol;

    for (self.symbol_patches.items) |patch_info| {
        if (patch_info.symbol.index != sym.index) continue;
        switch (patch_info.kind) {
            .abs64 => {
                const little = std.mem.nativeToLittle(u64, value);
                @memcpy(buffer[patch_info.offset .. patch_info.offset + 8], std.mem.asBytes(&little));
            },
        }
    }
}

/// Patches all uses of `sym` in the engine-owned finalized buffer and remembers the value.
pub fn patchInPlace(self: *Engine, sym: Symbol, value: u64) !void {
    if (sym.index >= self.symbols.items.len) return error.InvalidSymbol;
    self.symbols.items[sym.index].value = value;
    if (self.finalized_bytes != null) {
        try self.patch(self.finalized_bytes.?, sym, value);
    }
}

fn emit(self: *Engine, resolved_op: layout.ResolvedOp) !void {
    try lower.emit(resolved_op.op, resolved_op.branch_encoding, self.writer(), &self.written, .{
        .allocator = self.allocator,
        .fixups = &self.fixups,
        .symbol_patches = &self.symbol_patches,
    });
}

fn appendOp(self: *Engine, op: ir.Op) void {
    if (self.is_finalized) @panic("asm engine: cannot record instructions after finalize");
    self.ops.append(self.allocator, op) catch @panic("asm engine: out of memory while recording instruction");
}

fn applySymbolValues(self: *Engine) !void {
    for (self.symbols.items, 0..) |info, index| {
        if (info.value) |value| {
            try self.applySymbolValue(.{ .index = index }, value);
        }
    }
}

fn applySymbolValue(self: *Engine, sym: Symbol, value: u64) !void {
    const buffer = self.finalized_bytes orelse return error.NotFinalized;
    try self.patch(buffer, sym, value);
}

// Operations

/// Records a `mov` instruction.
pub fn mov(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .mov = .{ .dst = dst, .src = src } });
}

/// Records an `add` instruction.
pub fn add(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .add = .{ .dst = dst, .src = src } });
}

/// Records a `sub` instruction.
pub fn sub(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .sub = .{ .dst = dst, .src = src } });
}

/// Records a `cmp` instruction.
pub fn cmp(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .cmp = .{ .dst = dst, .src = src } });
}

/// Records a `lea` instruction.
pub fn lea(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .lea = .{ .dst = dst, .src = src } });
}

/// Records an `and` instruction.
pub fn @"and"(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .@"and" = .{ .dst = dst, .src = src } });
}

/// Records an `or` instruction.
pub fn @"or"(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .@"or" = .{ .dst = dst, .src = src } });
}

/// Records an `xor` instruction.
pub fn xor(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .xor = .{ .dst = dst, .src = src } });
}

/// Records a `test` instruction.
pub fn @"test"(self: *Engine, dst: Arg, src: Arg) void {
    self.appendOp(.{ .@"test" = .{ .dst = dst, .src = src } });
}

/// Records a `push` instruction.
pub fn push(self: *Engine, operand: Arg) void {
    self.appendOp(.{ .push = operand });
}

/// Records a `pop` instruction.
pub fn pop(self: *Engine, operand: Arg) void {
    self.appendOp(.{ .pop = operand });
}

/// Records an `inc` instruction.
pub fn inc(self: *Engine, operand: Arg) void {
    self.appendOp(.{ .inc = operand });
}

/// Records a `dec` instruction.
pub fn dec(self: *Engine, operand: Arg) void {
    self.appendOp(.{ .dec = operand });
}

/// Records a `jmp` instruction.
pub fn jmp(self: *Engine, target: JumpTarget) void {
    self.appendOp(.{ .jmp = target });
}

/// Records a conditional branch instruction.
pub fn jcc(self: *Engine, condition: Condition, target: JccTarget) void {
    self.appendOp(.{ .jcc = .{ .condition = condition, .target = target } });
}

/// Records a `call` instruction.
pub fn call(self: *Engine, target: CallTarget) void {
    self.appendOp(.{ .call = target });
}

/// Records a near `ret` instruction.
pub fn ret(self: *Engine) void {
    self.appendOp(.ret);
}

/// Records a `syscall` instruction.
pub fn syscall(self: *Engine) void {
    self.appendOp(.syscall);
}
