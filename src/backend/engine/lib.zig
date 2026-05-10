const std = @import("std");

const op_file = @import("op.zig");

/// Public entrypoint for the x86-64 assembly engine.
pub const Engine = @import("engine.zig").Engine;

/// Generic instruction operand accepted by the high-level engine API.
pub const Arg = op_file.Arg;
/// Scaled index used by branch memory operands.
pub const BranchIndex = op_file.BranchIndex;
/// Memory operand accepted by indirect `jmp` and `call` targets.
pub const BranchMemory = op_file.BranchMemory;
/// Register operand accepted by indirect `jmp` and `call` targets.
pub const BranchRegister = op_file.BranchRegister;
/// Target accepted by `call`.
pub const CallTarget = op_file.CallTarget;
/// Condition code accepted by `jcc`.
pub const Condition = op_file.Condition;
/// Immediate value wrapper used by `Arg.imm`.
pub const Immediate = op_file.Immediate;
/// Target accepted by `jcc`.
pub const JccTarget = op_file.JccTarget;
/// Target accepted by `jmp`.
pub const JumpTarget = op_file.JumpTarget;
/// Symbolic branch destination allocated by the engine.
pub const Label = op_file.Label;
/// Symbolic address patched after final machine code emission.
pub const Symbol = op_file.Symbol;
/// Sized memory operand used by the assembly API.
pub const Memory = op_file.Memory;
/// Explicit size tag for memory operands.
pub const MemSize = op_file.MemSize;
/// Relative branch target encoded as either a label or displacement.
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
