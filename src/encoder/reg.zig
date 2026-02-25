fn factory_reg_low3(comptime T: type) fn (value: T) u3 {
    return struct {
        fn inner(value: T) u3 {
            const intValue: u8 = @intFromEnum(value);
            return @intCast(intValue & 0b111);
        }
    }.inner;
}

fn factory_is_extended(comptime T: type) fn (value: T) bool {
    return struct {
        fn inner(value: T) bool {
            const intValue: u8 = @intFromEnum(value);
            return (intValue & 0b1000) != 0;
        }
    }.inner;
}

pub const RegisterIndex_64 = enum(u8) {
    // General-purpose registers
    RAX = 0,
    RCX = 1,
    RDX = 2,
    RBX = 3,
    RSP = 4,
    RBP = 5,
    RSI = 6,
    RDI = 7,
    // Extended registers (require REX prefix)
    R8 = 8,
    R9 = 9,
    R10 = 10,
    R11 = 11,
    R12 = 12,
    R13 = 13,
    R14 = 14,
    R15 = 15,

    pub inline fn need_rex(_: @This()) bool {
        return true;
    }

    pub fn is_high_register(_: @This()) bool {
        return false; // 64-bit registers don't have high byte variants
    }

    pub const reg_low3 = factory_reg_low3(@This());
    pub const is_extended = factory_is_extended(@This());
};

pub const RegisterIndex_32 = enum(u8) {
    // General-purpose registers
    EAX = 0,
    ECX = 1,
    EDX = 2,
    EBX = 3,
    ESP = 4,
    EBP = 5,
    ESI = 6,
    EDI = 7,
    // Extended registers (require REX prefix)
    R8D = 8,
    R9D = 9,
    R10D = 10,
    R11D = 11,
    R12D = 12,
    R13D = 13,
    R14D = 14,
    R15D = 15,

    pub fn need_rex(self: @This()) bool {
        return self.is_extended();
    }

    pub fn is_high_register(_: @This()) bool {
        return false; // 32-bit registers don't have high byte variants
    }

    pub const reg_low3 = factory_reg_low3(@This());
    pub const is_extended = factory_is_extended(@This());
};

pub const RegisterIndex_16 = enum(u8) {
    // General-purpose registers
    AX = 0,
    CX = 1,
    DX = 2,
    BX = 3,
    SP = 4,
    BP = 5,
    SI = 6,
    DI = 7,
    // Extended registers (require REX prefix)
    R8W = 8,
    R9W = 9,
    R10W = 10,
    R11W = 11,
    R12W = 12,
    R13W = 13,
    R14W = 14,
    R15W = 15,

    pub fn need_rex(self: @This()) bool {
        return self.is_extended();
    }

    pub fn is_high_register(_: @This()) bool {
        return false; // 16-bit registers don't have high byte variants
    }

    pub const reg_low3 = factory_reg_low3(@This());
    pub const is_extended = factory_is_extended(@This());
};

pub const RegisterIndex_8 = enum(u9) {
    // General-purpose registers
    AL = 0,
    CL = 1,
    DL = 2,
    BL = 3,

    // High byte are used as an 'hack' to keep using an enum to represent
    // registers, while still encoding the correct values for ModR/M byte.
    AH = 4 | 0b1_0000,
    CH = 5 | 0b1_0000,
    DH = 6 | 0b1_0000,
    BH = 7 | 0b1_0000,

    SPL = 4,
    BPL = 5,
    SIL = 6,
    DIL = 7,

    // Extended registers (require REX prefix)
    R8B = 8,
    R9B = 9,
    R10B = 10,
    R11B = 11,
    R12B = 12,
    R13B = 13,
    R14B = 14,
    R15B = 15,

    pub fn need_rex(self: @This()) bool {
        return self == .SPL or self == .BPL or self == .SIL or self == .DIL or self.is_extended();
    }

    pub fn is_high_register(self: @This()) bool {
        const value: u9 = @intFromEnum(self);
        return (value & 0b1_0000) != 0;
    }

    pub fn reg_low3(self: @This()) u3 {
        const intValue: u8 = @intCast(@intFromEnum(self) & 0b1111);
        return @intCast(intValue & 0b0111);
    }

    pub fn is_extended(self: @This()) bool {
        const value: u9 = @intFromEnum(self);

        return (value & 0b0_1000) != 0;
    }
};

pub const Memory_Offset = enum {
    B0,
};

pub fn Register_Memory(comptime R: type) type {
    return struct { reg: R, offset: Memory_Offset };
}

pub fn Register_Ext(comptime R: type) type {
    return union(enum) {
        reg: R,
        memory: struct {
            reg: R,
            offset: i32,
        },
        relative: i32,
        absolute: u64,
    };
}
