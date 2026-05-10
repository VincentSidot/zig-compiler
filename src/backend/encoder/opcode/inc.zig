//! Encoder module for INC instruction forms.
//! This is built from https://www.felixcloutier.com/x86/inc

const std = @import("std");

const error_file = @import("../error.zig");
const EncodingError = error_file.EncodingError;

const factory_file = @import("../factory.zig");
const factory_single = factory_file.factory_single;
const factory_single_rex_w = factory_file.factory_single_rex_w;

const register = @import("../reg.zig");

const RegisterMemory8 = register.RegisterMemory_8;
const RegisterMemory16 = register.RegisterMemory_16;
const RegisterMemory32 = register.RegisterMemory_32;
const RegisterMemory64 = register.RegisterMemory_64;

const OP = struct {
    const RM8: u8 = 0xFE; // /0
    const RM16_32_64: u8 = 0xFF; // /0
};

// inc r/m8 r/m16 r/m32 r/m64

pub const rm8 = factory_single(
    RegisterMemory8,
    0b000, // /0
    OP.RM8,
);

pub const rm16 = factory_single(
    RegisterMemory16,
    0b000, // /0
    OP.RM16_32_64,
);

pub const rm32 = factory_single(
    RegisterMemory32,
    0b000, // /0
    OP.RM16_32_64,
);

pub const rm64 = factory_single_rex_w(
    RegisterMemory64,
    0b000, // /0
    OP.RM16_32_64,
    true,
);
