const std = @import("std");

const ir = @import("ir.zig");

pub const ResolvedOp = struct {
    op: ir.Op,
    size: usize,
    offset: usize = 0,
};

pub fn computeOffsets(ops: []ResolvedOp) usize {
    var offset: usize = 0;

    for (ops) |*op| {
        op.offset = offset;
        offset += op.size;
    }

    return offset;
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
