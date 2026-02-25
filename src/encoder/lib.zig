const mov_file = @import("mov.zig");
const reg_file = @import("reg.zig");

pub const mov = mov_file.mov;

pub const EncodingError = error{
    InvalidOperand,
    WriterError,
};

pub const RegisterIndex_64 = reg_file.RegisterIndex_64;
pub const RegisterIndex_32 = reg_file.RegisterIndex_32;
pub const RegisterIndex_16 = reg_file.RegisterIndex_16;
pub const RegisterIndex_8 = reg_file.RegisterIndex_8;

test {
    const std = @import("std");

    const mov_testing = @import("tests/mov.zig");

    std.testing.refAllDecls(mov_testing);
}
