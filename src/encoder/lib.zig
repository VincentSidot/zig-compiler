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

test {
    const std = @import("std");

    const mov_testing = @import("tests/mov.zig");
    const add_testing = @import("tests/add.zig");
    const reg_testing = @import("tests/reg.zig");

    std.testing.refAllDecls(mov_testing);
    std.testing.refAllDecls(add_testing);
    std.testing.refAllDecls(reg_testing);
}
