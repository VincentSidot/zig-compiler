//! Encoder module for POP instruction forms.
//! This is built from https://www.felixcloutier.com/x86/pop

const std = @import("std");

const error_file = @import("../error.zig");
const EncodingError = error_file.EncodingError;

const factory_file = @import("../factory.zig");
const factory_single = factory_file.factory_single;

const register = @import("../reg.zig");

const Register16 = register.RegisterIndex_16;
const Register32 = register.RegisterIndex_32;
const Register64 = register.RegisterIndex_64;
const RegisterMemory16 = register.RegisterMemory_16;
const RegisterMemory32 = register.RegisterMemory_32;
const RegisterMemory64 = register.RegisterMemory_64;

const OP = struct {
    const REG: u8 = 0x58; // +rd
    const RM: u8 = 0x8F; // /0
};

/// pop r16/r32/r64
pub const r16 = factory_single(
    Register16,
    0, // Unused
    OP.REG,
);
pub const r32 = factory_single(
    Register32,
    0, // Unused
    OP.REG,
);
pub const r64 = factory_single(
    Register64,
    0, // Unused
    OP.REG,
);

pub const rm16 = factory_single(
    RegisterMemory16,
    0b000, // /0
    OP.RM,
);
pub const rm32 = factory_single(
    RegisterMemory32,
    0b000, // /0
    OP.RM,
);
pub const rm64 = factory_single(
    RegisterMemory64,
    0b000, // /0
    OP.RM,
);
