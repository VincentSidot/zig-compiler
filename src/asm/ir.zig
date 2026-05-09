const op_file = @import("op.zig");

pub const Arg = op_file.Arg;
pub const CallTarget = op_file.CallTarget;
pub const Condition = op_file.Condition;
pub const JccTarget = op_file.JccTarget;
pub const JumpTarget = op_file.JumpTarget;
pub const Label = op_file.Label;

pub const BranchEncoding = enum {
    rel8,
    rel32,
};

pub const Binary = struct {
    dst: Arg,
    src: Arg,
};

pub const ConditionalBranch = struct {
    condition: Condition,
    target: JccTarget,
};

pub const Op = union(enum) {
    bind: Label,

    mov: Binary,
    add: Binary,
    sub: Binary,
    cmp: Binary,
    lea: Binary,
    @"and": Binary,
    @"or": Binary,
    xor: Binary,
    @"test": Binary,

    push: Arg,
    pop: Arg,
    inc: Arg,
    dec: Arg,

    jmp: JumpTarget,
    jcc: ConditionalBranch,
    call: CallTarget,

    ret,
    syscall,
};
