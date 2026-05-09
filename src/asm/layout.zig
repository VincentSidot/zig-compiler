const std = @import("std");

const ir = @import("ir.zig");
const branch_helper = @import("helper/branch.zig");
const lower = @import("lower.zig");

/// Per-label metadata tracked during layout and fixup resolution.
pub const LabelInfo = branch_helper.LabelInfo;

/// Chosen branch encoding after layout relaxation.
pub const BranchEncoding = ir.BranchEncoding;

/// Instruction plus the layout metadata needed for emission.
pub const ResolvedOp = struct {
    op: ir.Op,
    size: usize,
    offset: usize = 0,
    branch_encoding: ?BranchEncoding = null,
};

/// Resolves IR operations into sized instructions with default branch encodings.
pub fn resolveOps(allocator: std.mem.Allocator, ops: []const ir.Op) ![]ResolvedOp {
    var resolved = std.ArrayList(ResolvedOp).empty;
    errdefer resolved.deinit(allocator);

    for (ops) |op| {
        try resolved.append(allocator, .{
            .op = op,
            .size = try lower.sizeOf(allocator, op, null),
            .branch_encoding = defaultBranchEncoding(op),
        });
    }

    return try resolved.toOwnedSlice(allocator);
}

/// Computes byte offsets for the provided instruction sequence and returns the total size.
pub fn computeOffsets(ops: []ResolvedOp) usize {
    var offset: usize = 0;

    for (ops) |*op| {
        op.offset = offset;
        offset += op.size;
    }

    return offset;
}

/// Records final label offsets from the resolved instruction stream.
pub fn resolveLabels(labels: []LabelInfo, ops: []const ResolvedOp) !void {
    for (ops) |op| {
        switch (op.op) {
            .bind => |label| {
                if (label.index >= labels.len) return error.InvalidLabel;
                labels[label.index].offset = op.offset;
            },
            else => {},
        }
    }
}

/// Performs branch relaxation passes and returns the number of passes.
pub fn relaxLayout(allocator: std.mem.Allocator, ops: []ResolvedOp, labels: []LabelInfo) !usize {
    var step: usize = 0;
    while (true) {
        step += 1;
        _ = computeOffsets(ops);
        try resolveLabels(labels, ops);

        const changed = try relaxBranches(allocator, ops, labels);
        if (!changed) break;
    }

    return step;
}

/// Shrinks relaxable label branches from `rel32` to `rel8` when the final displacement fits.
pub fn relaxBranches(allocator: std.mem.Allocator, ops: []ResolvedOp, labels: []const LabelInfo) !bool {
    var changed = false;

    for (ops) |*op| {
        if (op.branch_encoding != .rel32) continue;
        if (!try canRelaxToRel8(op.*, labels)) continue;

        op.branch_encoding = .rel8;
        op.size = try lower.sizeOf(allocator, op.op, op.branch_encoding);
        changed = true;
    }

    return changed;
}

/// Returns whether a resolved label branch can be encoded as `rel8`.
pub fn canRelaxToRel8(op: ResolvedOp, labels: []const LabelInfo) !bool {
    const label = branchLabel(op.op) orelse return false;
    if (label.index >= labels.len) return error.InvalidLabel;
    const target_offset = labels[label.index].offset orelse return error.UnresolvedLabel;

    const next_offset = op.offset + op.size;
    const disp = @as(i64, @intCast(target_offset)) - @as(i64, @intCast(next_offset));

    return std.math.cast(i8, disp) != null;
}

fn defaultBranchEncoding(op: ir.Op) ?BranchEncoding {
    return if (branchLabel(op) != null) .rel32 else null;
}

fn branchLabel(op: ir.Op) ?ir.Label {
    return switch (op) {
        .jmp => |target| switch (target) {
            .label => |label| label,
            else => null,
        },
        .jcc => |branch| switch (branch.target) {
            .label => |label| label,
            else => null,
        },
        else => null,
    };
}

test "asm layout computes offsets from resolved sizes" {
    var ops = [_]ResolvedOp{
        .{ .op = .ret, .size = 1 },
        .{ .op = .syscall, .size = 2 },
        .{ .op = .ret, .size = 1 },
    };

    const total = computeOffsets(&ops);

    try std.testing.expectEqual(@as(usize, 4), total);
    try std.testing.expectEqual(@as(usize, 0), ops[0].offset);
    try std.testing.expectEqual(@as(usize, 1), ops[1].offset);
    try std.testing.expectEqual(@as(usize, 3), ops[2].offset);
}

test "asm layout resolves labels from op offsets" {
    const label = ir.Label{ .index = 0 };
    var labels = [_]LabelInfo{.{}};
    const ops = [_]ResolvedOp{
        .{ .op = .ret, .size = 1, .offset = 0 },
        .{ .op = .{ .bind = label }, .size = 0, .offset = 1 },
    };

    try resolveLabels(&labels, &ops);

    try std.testing.expectEqual(@as(?usize, 1), labels[0].offset);
}

test "asm layout rejects invalid label during resolution" {
    const label = ir.Label{ .index = 1 };
    var labels = [_]LabelInfo{.{}};
    const ops = [_]ResolvedOp{
        .{ .op = .{ .bind = label }, .size = 0, .offset = 0 },
    };

    try std.testing.expectError(error.InvalidLabel, resolveLabels(&labels, &ops));
}

test "asm layout resolves op sizes" {
    const Arg = ir.Arg;

    const ops = [_]ir.Op{
        .{ .mov = .{ .dst = .rax, .src = Arg.immediate(1) } },
        .ret,
        .syscall,
    };

    const resolved = try resolveOps(std.testing.allocator, &ops);
    defer std.testing.allocator.free(resolved);

    try std.testing.expectEqual(@as(usize, 7), resolved[0].size);
    try std.testing.expectEqual(@as(usize, 1), resolved[1].size);
    try std.testing.expectEqual(@as(usize, 2), resolved[2].size);
}

test "asm layout marks relaxable label branches as rel32 by default" {
    const label = ir.Label{ .index = 0 };
    const ops = [_]ir.Op{
        .{ .jmp = .{ .label = label } },
        .{ .jcc = .{ .condition = .e, .target = .{ .label = label } } },
        .{ .call = .{ .label = label } },
        .{ .jmp = .{ .rel = 1 } },
    };

    const resolved = try resolveOps(std.testing.allocator, &ops);
    defer std.testing.allocator.free(resolved);

    try std.testing.expectEqual(BranchEncoding.rel32, resolved[0].branch_encoding.?);
    try std.testing.expectEqual(BranchEncoding.rel32, resolved[1].branch_encoding.?);
    try std.testing.expectEqual(@as(?BranchEncoding, null), resolved[2].branch_encoding);
    try std.testing.expectEqual(@as(?BranchEncoding, null), resolved[3].branch_encoding);
}

test "asm layout checks rel8 relaxation eligibility" {
    const label = ir.Label{ .index = 0 };
    var labels = [_]LabelInfo{.{ .offset = 10, .bound = true }};

    const close = ResolvedOp{
        .op = .{ .jmp = .{ .label = label } },
        .size = 5,
        .offset = 0,
        .branch_encoding = .rel32,
    };
    const far = ResolvedOp{
        .op = .{ .jmp = .{ .label = label } },
        .size = 5,
        .offset = 500,
        .branch_encoding = .rel32,
    };
    const non_branch = ResolvedOp{
        .op = .ret,
        .size = 1,
        .offset = 0,
    };

    try std.testing.expect(try canRelaxToRel8(close, &labels));
    try std.testing.expect(!try canRelaxToRel8(far, &labels));
    try std.testing.expect(!try canRelaxToRel8(non_branch, &labels));
}

test "asm layout relaxes eligible label branches to rel8 metadata" {
    const label = ir.Label{ .index = 0 };
    var labels = [_]LabelInfo{.{ .bound = true }};
    var ops = [_]ResolvedOp{
        .{
            .op = .{ .jmp = .{ .label = label } },
            .size = 5,
            .branch_encoding = .rel32,
        },
        .{
            .op = .{ .bind = label },
            .size = 0,
        },
    };

    _ = try relaxLayout(std.testing.allocator, &ops, &labels);

    try std.testing.expectEqual(BranchEncoding.rel8, ops[0].branch_encoding.?);
    try std.testing.expectEqual(@as(usize, 2), ops[0].size);
    try std.testing.expectEqual(@as(?usize, 2), labels[0].offset);
}

test "asm layout keeps distant label branches rel32 metadata" {
    const label = ir.Label{ .index = 0 };
    var labels = [_]LabelInfo{.{ .bound = true }};
    var ops = [_]ResolvedOp{
        .{
            .op = .{ .jmp = .{ .label = label } },
            .size = 5,
            .branch_encoding = .rel32,
        },
        .{
            .op = .syscall,
            .size = 200,
        },
        .{
            .op = .{ .bind = label },
            .size = 0,
        },
    };

    _ = try relaxLayout(std.testing.allocator, &ops, &labels);

    try std.testing.expectEqual(BranchEncoding.rel32, ops[0].branch_encoding.?);
    try std.testing.expectEqual(@as(?usize, 205), labels[0].offset);
}

test "asm layout relaxation repeats until newly eligible branches shrink" {
    const after_inner = ir.Label{ .index = 0 };
    const target = ir.Label{ .index = 1 };
    var labels = [_]LabelInfo{
        .{ .bound = true },
        .{ .bound = true },
    };
    var ops = [_]ResolvedOp{
        .{
            .op = .{ .jmp = .{ .label = target } },
            .size = 5,
            .branch_encoding = .rel32,
        },
        .{
            .op = .{ .jmp = .{ .label = after_inner } },
            .size = 5,
            .branch_encoding = .rel32,
        },
        .{
            .op = .{ .bind = after_inner },
            .size = 0,
        },
        .{
            .op = .syscall,
            .size = 123,
        },
        .{
            .op = .{ .bind = target },
            .size = 0,
        },
    };

    const passes = try relaxLayout(std.testing.allocator, &ops, &labels);

    try std.testing.expectEqual(@as(usize, 3), passes);
    try std.testing.expectEqual(BranchEncoding.rel8, ops[0].branch_encoding.?);
    try std.testing.expectEqual(BranchEncoding.rel8, ops[1].branch_encoding.?);
    try std.testing.expectEqual(@as(?usize, 4), labels[0].offset);
    try std.testing.expectEqual(@as(?usize, 127), labels[1].offset);
}
