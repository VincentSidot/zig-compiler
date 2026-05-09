const std = @import("std");

const op_file = @import("op.zig");

pub const Engine = @import("engine.zig").Engine;

pub const Arg = op_file.Arg;
pub const BranchIndex = op_file.BranchIndex;
pub const BranchMemory = op_file.BranchMemory;
pub const BranchRegister = op_file.BranchRegister;
pub const CallTarget = op_file.CallTarget;
pub const Condition = op_file.Condition;
pub const Immediate = op_file.Immediate;
pub const JccTarget = op_file.JccTarget;
pub const JumpTarget = op_file.JumpTarget;
pub const Label = op_file.Label;
pub const Memory = op_file.Memory;
pub const MemSize = op_file.MemSize;
pub const RelativeTarget = op_file.RelativeTarget;

test {
    std.testing.refAllDecls(@import("op.zig"));
    std.testing.refAllDecls(@import("ir.zig"));
    std.testing.refAllDecls(@import("layout.zig"));
    std.testing.refAllDecls(@import("lower.zig"));
    std.testing.refAllDecls(@import("engine.zig"));

    std.testing.refAllDecls(@import("helper/add.zig"));
    std.testing.refAllDecls(@import("helper/binary.zig"));
    std.testing.refAllDecls(@import("helper/bit.zig"));
    std.testing.refAllDecls(@import("helper/branch.zig"));
    std.testing.refAllDecls(@import("helper/cmp.zig"));
    std.testing.refAllDecls(@import("helper/lea.zig"));
    std.testing.refAllDecls(@import("helper/mov.zig"));
    std.testing.refAllDecls(@import("helper/ret.zig"));
    std.testing.refAllDecls(@import("helper/single.zig"));
    std.testing.refAllDecls(@import("helper/sub.zig"));
    std.testing.refAllDecls(@import("helper/syscall.zig"));
    std.testing.refAllDecls(@import("helper/xor.zig"));

    std.testing.refAllDecls(@import("tests.zig"));
}
