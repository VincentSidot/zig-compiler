const std = @import("std");
const Writer = std.io.Writer;

const error_file = @import("error.zig");
const EncodingError = error_file.EncodingError;

fn factory_reg_low3(comptime T: type) fn (value: T) callconv(.@"inline") u3 {
    return struct {
        inline fn inner(value: T) u3 {
            const intValue: u8 = @intFromEnum(value);
            return @intCast(intValue & 0b111);
        }
    }.inner;
}

fn factory_is_extended(comptime T: type) fn (value: T) callconv(.@"inline") bool {
    return struct {
        inline fn inner(value: T) bool {
            const intValue: u8 = @intFromEnum(value);
            return (intValue & 0b1000) != 0;
        }
    }.inner;
}

pub const RegisterIndex_64 = enum(u8) {
    const Self = @This();

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

    pub inline fn need_rex(_: Self) bool {
        return true;
    }

    pub inline fn is_high_register(_: Self) bool {
        return false; // 64-bit registers don't have high byte variants
    }

    pub const reg_low3 = factory_reg_low3(Self);
    pub const is_extended = factory_is_extended(Self);
};

pub const RegisterIndex_32 = enum(u8) {
    const Self = @This();

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

    pub inline fn need_rex(self: Self) bool {
        return self.is_extended();
    }

    pub inline fn is_high_register(_: Self) bool {
        return false; // 32-bit registers don't have high byte variants
    }

    pub const reg_low3 = factory_reg_low3(Self);
    pub const is_extended = factory_is_extended(Self);
};

pub const RegisterIndex_16 = enum(u8) {
    const Self = @This();

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

    pub inline fn need_rex(self: Self) bool {
        return self.is_extended();
    }

    pub inline fn is_high_register(_: Self) bool {
        return false; // 16-bit registers don't have high byte variants
    }

    pub const reg_low3 = factory_reg_low3(Self);
    pub const is_extended = factory_is_extended(Self);
};

pub const RegisterIndex_8 = enum(u9) {
    const Self = @This();

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

    pub inline fn need_rex(self: Self) bool {
        return self == .SPL or self == .BPL or self == .SIL or self == .DIL or self.is_extended();
    }

    pub inline fn is_high_register(self: Self) bool {
        const value: u9 = @intFromEnum(self);
        return (value & 0b1_0000) != 0;
    }

    pub fn reg_low3(self: Self) u3 {
        const intValue: u8 = @intCast(@intFromEnum(self) & 0b1111);
        return @intCast(intValue & 0b0111);
    }

    pub fn is_extended(self: Self) bool {
        const value: u9 = @intFromEnum(self);

        return (value & 0b0_1000) != 0;
    }
};

pub const Scale = enum(u2) {
    x1 = 0,
    x2 = 1,
    x4 = 2,
    x8 = 3,
};

pub const Index = struct {
    reg: RegisterIndex_64,
    scale: Scale = .x1,

    pub inline fn validate(self: Index) EncodingError!void {
        if (self.reg == .RSP or self.reg == .R12) {
            return EncodingError.InvalidIndexRegister;
        }
    }
};

/// Represents a memory operand in x86-64 assembly, which can be of the form:
/// [base + index*scale + disp] or [RIP + disp] for RIP-relative addressing.
/// - base: Optional base register (e.g., RAX, RBX)
/// - index: Optional index register (e.g., RAX, RBX)
/// - scale: Scale factor for the index register (1, 2, 4, or 8)
/// - disp: Displacement (can be positive or negative)
///
/// # Notes:
/// - RSP/R12 cannot be used as index registers.
pub const BaseIndexMemory = struct {
    base: ?RegisterIndex_64 = null, // Base register (optional)
    index: ?Index = null, // Index register (optional)
    disp: i32 = 0, // Displacement (can be positive or negative)

    pub inline fn validate(self: BaseIndexMemory) EncodingError!void {
        if (self.index) |idx| {
            try idx.validate();
        }
    }
};

pub const RipRelativeMemory = struct {
    disp: i32 = 0, // Displacement for RIP-relative addressing

    pub inline fn validate(self: RipRelativeMemory) EncodingError!void {
        _ = self;
        // No specific validation needed for RIP-relative addressing.
    }
};

pub const Memory = union(enum) {
    baseIndex: BaseIndexMemory,
    ripRelative: RipRelativeMemory,

    pub inline fn validate(self: Memory) EncodingError!void {
        return switch (self) {
            .baseIndex => |mem| mem.validate(),
            .ripRelative => |mem| mem.validate(),
        };
    }
};

fn RegMem(comptime R: type) type {
    return union(enum) {
        const Self = @This();
        reg: R,
        mem: Memory,

        pub inline fn validate(self: Self) EncodingError!void {
            return switch (self) {
                .reg => |_| {},
                .mem => |mem| mem.validate(),
            };
        }

        pub inline fn need_rex(self: Self) bool {
            return switch (self) {
                .reg => |r| r.need_rex(),
                .mem => |_| {
                    // Not implemented yet
                    @panic("Memory operand REX prefix check not implemented");
                },
            };
        }

        pub inline fn is_high_register(self: Self) bool {
            return switch (self) {
                .reg => |r| r.is_high_register(),
                .mem => |_| false, // Memory operands cannot be high registers
            };
        }

        pub inline fn is_extended(self: Self) bool {
            return switch (self) {
                .reg => |r| r.is_extended(),
                .mem => |_| {
                    // Not implemented yet
                    @panic("Memory operand extended register check not implemented");
                },
            };
        }
    };
}

pub const RegisterMemory_64 = RegMem(RegisterIndex_64);
pub const RegisterMemory_32 = RegMem(RegisterIndex_32);
pub const RegisterMemory_16 = RegMem(RegisterIndex_16);
pub const RegisterMemory_8 = RegMem(RegisterIndex_8);

pub fn is_memory_register(comptime T: type) bool {
    const name = @typeName(T);
    return std.mem.indexOf(u8, name, "RegMem(") != null;
}

pub fn is_index_register(comptime T: type) bool {
    const name = @typeName(T);
    return std.mem.indexOf(u8, name, "RegisterIndex_") != null;
}

pub fn fetch_index_register(comptime Mem: type) type {
    ensure_mem_reg(Mem);

    inline for (@typeInfo(Mem).@"union".fields) |field| {
        if (std.mem.eql(u8, field.name, "reg")) return field.type;
    }

    @compileError("Unable to extract register type from memory register union");
}

pub fn ensure_mem_reg(comptime Mem: type) void {
    comptime {
        if (!is_memory_register(Mem)) {
            const memTypeName = @typeName(Mem);
            const errorMessage = std.fmt.comptimePrint(
                "Expected a memory register type, but got: {s}",
                .{memTypeName},
            );
            @compileError(errorMessage);
        }
    }
}

pub fn ensure_index_reg(comptime Reg: type) void {
    comptime {
        if (!is_index_register(Reg)) {
            const regTypeName = @typeName(Reg);
            const errorMessage = std.fmt.comptimePrint(
                "Expected an index register type, but got: {s}",
                .{regTypeName},
            );

            @compileError(errorMessage);
        }
    }
}

pub fn ensure_matching_reg(comptime Mem: type, comptime Reg: type) void {
    comptime {
        if (fetch_index_register(Mem) != Reg) {
            const memTypeName = @typeName(Mem);
            const regTypeName = @typeName(Reg);
            const errorMessage = std.fmt.comptimePrint(
                "The reg operand type ({s}) must match the index register type of the memory operand ({s})",
                .{ regTypeName, memTypeName },
            );

            @compileError(errorMessage);
        }
    }
}

/// ModRM byte encoding:
/// mod: addressing mode (2 bits)
/// reg: register operand (3 bits)
/// rm: r/m operand (3 bits)
fn modrm(mod: u8, reg3: u8, rm3: u8) u8 {
    // mod (2 bits) in bits 7..6
    // reg (3 bits) in bits 5..3
    // rm  (3 bits) in bits 2..0
    return ((mod & 0x3) << 6) | ((reg3 & 0x7) << 3) | (rm3 & 0x7);
}

pub fn emit_modrm_sib(
    /// Reg operand type (e.g., RegisterIndex_64, RegisterIndex_32, etc.)
    /// Note: You can also use void if you want to force a 0 in the reg field
    /// of the ModR/M byte, which is useful for certain instructions that don't
    /// use the reg field.
    comptime Reg: type,
    comptime Mem: type,
    writer: *Writer,
    /// In case of Reg being void, pass undefined here to satisfy the type
    /// system, but it will be ignored.
    reg: Reg,
    rm: Mem,
) EncodingError!usize {
    // Comptime type validation to ensure correct usage of the function.
    ensure_mem_reg(Mem);
    if (Reg != void) {
        ensure_index_reg(Reg);
        ensure_matching_reg(Mem, Reg);
    }

    switch (rm) {
        .reg => |rm_reg| {
            const mod = 0b11; // Register addressing mode
            var reg3: u3 = undefined;

            if (Reg != void) {
                reg3 = reg.reg_low3();
            } else {
                // If Reg is void, we set reg3 to 0, which is often used for
                // instructions that don't utilize the reg field.
                reg3 = 0;
            }

            const rm3 = rm_reg.reg_low3();
            const modrm_byte = modrm(mod, reg3, rm3);

            writer.writeByte(modrm_byte) catch {
                return EncodingError.WriterError;
            };
            return 1; // Number of bytes written
        },
        .mem => |rm_mem| {
            _ = rm_mem; // Not implemented yet, but this is where we would handle memory operand encoding.
            @panic("Memory operand encoding not implemented yet");
        },
    }
}
