const reg_file = @import("reg.zig");
const helper_file = @import("helper.zig");
const error_file = @import("error.zig");

pub const opcode = @import("opcode.zig");

pub const EncodingError = error_file.EncodingError;

pub const RegisterIndex_64 = reg_file.RegisterIndex_64;
pub const RegisterIndex_32 = reg_file.RegisterIndex_32;
pub const RegisterIndex_16 = reg_file.RegisterIndex_16;
pub const RegisterIndex_8 = reg_file.RegisterIndex_8;
pub const RegisterMemory_64 = reg_file.RegisterMemory_64;
pub const RegisterMemory_32 = reg_file.RegisterMemory_32;
pub const RegisterMemory_16 = reg_file.RegisterMemory_16;
pub const RegisterMemory_8 = reg_file.RegisterMemory_8;

pub const extractBits = helper_file.extractBits;

pub const register = struct {
    pub const r64 = RegisterIndex_64;
    pub const r32 = RegisterIndex_32;
    pub const r16 = RegisterIndex_16;
    pub const r8 = RegisterIndex_8;

    pub const m64 = RegisterMemory_64;
    pub const m32 = RegisterMemory_32;
    pub const m16 = RegisterMemory_16;
    pub const m8 = RegisterMemory_8;
};

test {
    const std = @import("std");

    const mov_testing = @import("tests/mov.zig");
    const add_testing = @import("tests/add.zig");
    const sub_testing = @import("tests/sub.zig");
    const cmp_testing = @import("tests/cmp.zig");
    const call_testing = @import("tests/call.zig");
    const jmp_testing = @import("tests/jmp.zig");
    const jcc_testing = @import("tests/jcc.zig");
    const push_testing = @import("tests/push.zig");
    const pop_testing = @import("tests/pop.zig");
    const lea_testing = @import("tests/lea.zig");
    const bitwise_testing = @import("tests/bitwise.zig");
    const reg_testing = @import("tests/reg.zig");

    std.testing.refAllDecls(mov_testing);
    std.testing.refAllDecls(add_testing);
    std.testing.refAllDecls(sub_testing);
    std.testing.refAllDecls(cmp_testing);
    std.testing.refAllDecls(call_testing);
    std.testing.refAllDecls(jmp_testing);
    std.testing.refAllDecls(jcc_testing);
    std.testing.refAllDecls(push_testing);
    std.testing.refAllDecls(pop_testing);
    std.testing.refAllDecls(lea_testing);
    std.testing.refAllDecls(bitwise_testing);
    std.testing.refAllDecls(reg_testing);
}
