const std = @import("std");

const reg_file = @import("../reg.zig");
const error_file = @import("../error.zig");

const EncodingError = error_file.EncodingError;

const RegisterIndex_64 = reg_file.RegisterIndex_64;
const Scale = reg_file.Scale;
const Index = reg_file.Index;
const Memory = reg_file.Memory;
const RegMem64 = reg_file.RegMem(RegisterIndex_64);

test "RegMem validate accepts register operand" {
    const op: RegMem64 = .{ .reg = .RAX };
    try op.validate();
}

test "RegMem validate accepts base/index memory operand" {
    const op: RegMem64 = .{
        .mem = .{
            .baseIndex = .{
                .base = .RAX,
                .index = .{ .reg = .RCX, .scale = .x4 },
                .disp = 16,
            },
        },
    };

    try op.validate();
}

test "RegMem validate accepts RIP-relative memory operand" {
    const op: RegMem64 = .{
        .mem = .{
            .ripRelative = .{
                .disp = 32,
            },
        },
    };

    try op.validate();
}

test "RegMem validate rejects RSP as index register" {
    const op: RegMem64 = .{
        .mem = .{
            .baseIndex = .{
                .base = .RAX,
                .index = .{ .reg = .RSP, .scale = .x2 },
            },
        },
    };

    try std.testing.expectError(EncodingError.InvalidIndexRegister, op.validate());
}

test "RegMem validate rejects R12 as index register" {
    const op: RegMem64 = .{
        .mem = .{
            .baseIndex = .{
                .base = .RAX,
                .index = .{ .reg = .R12, .scale = .x8 },
            },
        },
    };

    try std.testing.expectError(EncodingError.InvalidIndexRegister, op.validate());
}

test "Index validate accepts non-restricted index register" {
    const idx: Index = .{ .reg = .R13, .scale = Scale.x2 };
    try idx.validate();
}
