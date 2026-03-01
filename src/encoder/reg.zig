const std = @import("std");
const Writer = std.io.Writer;

const error_file = @import("error.zig");
const EncodingError = error_file.EncodingError;

const arithmetic_file = @import("arithmetic.zig");
const extractBits = arithmetic_file.extractBits;

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

// Operand-size override prefix for 32-bit addressing in 64-bit mode
pub const BIT32_ADDRESSING_PREFIX: u8 = 0x67;

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

pub const Index_64 = struct {
    reg: RegisterIndex_64,
    scale: Scale = .x1,

    pub inline fn validate(self: Index_64) EncodingError!void {
        if (self.reg == .RSP) {
            return EncodingError.InvalidIndexRegister;
        }
    }

    pub inline fn need_index(self: Index_64) bool {
        return self.reg.need_rex() and self.reg != .RSP;
    }

    pub inline fn is_extended(self: Index_64) bool {
        return self.reg.is_extended();
    }
};

pub const Index_32 = struct {
    reg: RegisterIndex_32,
    scale: Scale = .x1,

    pub inline fn validate(self: Index_32) EncodingError!void {
        if (self.reg == .ESP) {
            return EncodingError.InvalidIndexRegister;
        }
    }

    pub inline fn need_index(self: Index_32) bool {
        return self.reg.need_rex() and self.reg != .ESP;
    }

    pub inline fn is_extended(self: Index_32) bool {
        return self.reg.is_extended();
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
/// - RSP cannot be used as index registers.
pub const BaseIndexMemory_64 = struct {
    base: ?RegisterIndex_64 = null, // Base register (optional)
    index: ?Index_64 = null, // Index register (optional)
    disp: i32 = 0, // Displacement (can be positive or negative)

    pub inline fn validate(self: BaseIndexMemory_64) EncodingError!void {
        if (self.index) |idx| {
            try idx.validate();
        }
    }

    pub inline fn base_requires_sib(self: BaseIndexMemory_64) bool {
        return self.base == .RSP or self.base == .R12;
    }

    pub inline fn need_index(self: BaseIndexMemory_64) bool {
        if (self.index) |idx| {
            return idx.need_index();
        } else {
            return false;
        }
    }

    pub inline fn need_base(self: BaseIndexMemory_64) bool {
        return self.base != null;
    }

    pub inline fn rex_b(self: BaseIndexMemory_64) bool {
        if (self.base) |baseReg| {
            return baseReg.is_extended();
        }
        return false;
    }

    pub inline fn rex_x(self: BaseIndexMemory_64) bool {
        if (self.index) |idx| {
            return idx.is_extended();
        }
        return false;
    }

    pub inline fn need_rex(self: BaseIndexMemory_64) bool {
        return self.rex_b() or self.rex_x();
    }

    pub inline fn is_extended(self: BaseIndexMemory_64) bool {
        if (self.base) |baseReg| {
            if (baseReg.is_extended()) {
                return true;
            }
        }

        if (self.index) |idx| {
            if (idx.is_extended()) {
                return true;
            }
        }

        return false;
    }
};

pub const BaseIndexMemory_32 = struct {
    base: ?RegisterIndex_32 = null, // Base register (optional)
    index: ?Index_32 = null, // Index register (optional)
    disp: i32 = 0, // Displacement (can be positive or negative)

    pub inline fn validate(self: BaseIndexMemory_32) EncodingError!void {
        if (self.index) |idx| {
            try idx.validate();
        }
    }

    pub inline fn base_requires_sib(self: BaseIndexMemory_32) bool {
        return self.base == .ESP or self.base == .R12D;
    }

    pub inline fn need_index(self: BaseIndexMemory_32) bool {
        if (self.index) |idx| {
            return idx.need_index();
        } else {
            return false;
        }
    }

    pub inline fn need_base(self: BaseIndexMemory_32) bool {
        return self.base != null;
    }

    pub inline fn is_extended(self: BaseIndexMemory_32) bool {
        if (self.base) |baseReg| {
            if (baseReg.is_extended()) {
                return true;
            }
        }

        if (self.index) |idx| {
            if (idx.is_extended()) {
                return true;
            }
        }

        return false;
    }

    pub inline fn rex_b(self: BaseIndexMemory_32) bool {
        if (self.base) |baseReg| {
            return baseReg.is_extended();
        }
        return false;
    }

    pub inline fn rex_x(self: BaseIndexMemory_32) bool {
        if (self.index) |idx| {
            return idx.is_extended();
        }
        return false;
    }

    pub inline fn need_rex(self: BaseIndexMemory_32) bool {
        return self.rex_b() or self.rex_x();
    }
};

pub const RipRelativeMemory = i32;

pub const Memory = union(enum) {
    baseIndex32: BaseIndexMemory_32,
    baseIndex64: BaseIndexMemory_64,
    ripRelative: RipRelativeMemory,

    pub inline fn validate(self: Memory) EncodingError!void {
        return switch (self) {
            .baseIndex32 => |mem32| mem32.validate(),
            .baseIndex64 => |mem64| mem64.validate(),
            // No validation needed for RIP-relative memory
            .ripRelative => |_| {},
        };
    }

    pub inline fn need_index(self: Memory) bool {
        return switch (self) {
            .baseIndex32 => |mem32| mem32.need_index(),
            .baseIndex64 => |mem64| mem64.need_index(),
            .ripRelative => |_| false, // RIP-relative addressing does not use index registers
        };
    }

    pub inline fn need_base(self: Memory) bool {
        return switch (self) {
            .baseIndex32 => |mem32| mem32.need_base(),
            .baseIndex64 => |mem64| mem64.need_base(),
            .ripRelative => |_| false, // RIP-relative addressing does not use base registers
        };
    }

    pub inline fn need_rex(self: Memory) bool {
        return switch (self) {
            .baseIndex32 => |mem32| {
                return mem32.need_rex();
            },
            .baseIndex64 => |mem64| {
                return mem64.need_rex();
            },
            .ripRelative => |_| false, // RIP-relative addressing does not require REX prefix
        };
    }

    pub inline fn rex_b(self: Memory) bool {
        return switch (self) {
            .baseIndex32 => |mem32| mem32.rex_b(),
            .baseIndex64 => |mem64| mem64.rex_b(),
            .ripRelative => |_| false,
        };
    }

    pub inline fn rex_x(self: Memory) bool {
        return switch (self) {
            .baseIndex32 => |mem32| mem32.rex_x(),
            .baseIndex64 => |mem64| mem64.rex_x(),
            .ripRelative => |_| false,
        };
    }

    pub inline fn is_extended(self: Memory) bool {
        switch (self) {
            .baseIndex32 => |mem32| {
                return mem32.is_extended();
            },
            .baseIndex64 => |mem64| {
                return mem64.is_extended();
            },
            .ripRelative => |_| {
                return false;
            }, // RIP-relative addressing does not involve registers
        }
    }

    pub inline fn is_memory32(self: Memory) bool {
        switch (self) {
            .baseIndex32 => |_| {
                return true;
            },
            .baseIndex64 => |_| {
                return false;
            },
            .ripRelative => |_| {
                return false;
            },
        }
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
                .mem => |m| m.validate(),
            };
        }

        pub inline fn is_memory32(self: Self) bool {
            switch (self) {
                .reg => |_| {
                    return false;
                },
                .mem => |m| {
                    return m.is_memory32();
                },
            }
        }

        pub inline fn need_rex(self: Self) bool {
            return switch (self) {
                .reg => |r| r.need_rex(),
                .mem => |m| m.need_rex(),
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
                .mem => |m| m.is_extended(),
            };
        }

        pub inline fn rex_b(self: Self) bool {
            return switch (self) {
                .reg => |r| r.is_extended(),
                .mem => |m| m.rex_b(),
            };
        }

        pub inline fn rex_x(self: Self) bool {
            return switch (self) {
                .reg => |_| false,
                .mem => |m| m.rex_x(),
            };
        }
    };
}

pub const RegisterMemory_64 = RegMem(RegisterIndex_64);
pub const RegisterMemory_32 = RegMem(RegisterIndex_32);
pub const RegisterMemory_16 = RegMem(RegisterIndex_16);
pub const RegisterMemory_8 = RegMem(RegisterIndex_8);

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

fn sib(scale: u8, index: u8, base: u8) u8 {
    // scale (2 bits) in bits 7..6
    // index (3 bits) in bits 5..3
    // base  (3 bits) in bits 2..0
    return ((scale & 0x3) << 6) | ((index & 0x7) << 3) | (base & 0x7);
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
    if (Reg != void) {
        ensure_index_reg(Reg);
    }

    var written: usize = undefined;

    try rm.validate();

    switch (rm) {
        .reg => |rm_reg| {
            written = try emit_modrm_sib_reg_only(
                Reg,
                @TypeOf(rm_reg),
                writer,
                reg,
                rm_reg,
            );
        },
        .mem => |rm_mem| {
            switch (rm_mem) {
                .baseIndex32 => |rm_mem_base_index| {
                    written = try emit_modrm_sib_base_index(
                        Reg,
                        BaseIndexMemory_32,
                        writer,
                        reg,
                        rm_mem_base_index,
                    );
                },
                .baseIndex64 => |rm_mem_base_index| {
                    written = try emit_modrm_sib_base_index(
                        Reg,
                        BaseIndexMemory_64,
                        writer,
                        reg,
                        rm_mem_base_index,
                    );
                },
                .ripRelative => |rm_mem_rip| {
                    written = try emit_modrm_sib_rip_relative(
                        Reg,
                        writer,
                        reg,
                        rm_mem_rip,
                    );
                },
            }
        },
    }

    return written;
}

fn emit_modrm_sib_reg_only(
    comptime Reg: type,
    comptime Mem: type,
    writer: *Writer,
    reg: Reg,
    rm_reg: Mem,
) EncodingError!usize {
    ensure_index_reg(Mem);
    if (Reg != void) {
        ensure_matching_reg(Mem, Reg);
    }

    // Compute components
    const mod = 0b11; // Register addressing mode
    const reg3: u3 = compute_reg3(Reg, reg);
    const rm3: u3 = rm_reg.reg_low3();

    // Encode ModR/M byte
    const modrm_byte = modrm(mod, reg3, rm3);

    writer.writeByte(modrm_byte) catch {
        return EncodingError.WriterError;
    };
    return 1; // Number of bytes written
}

fn emit_modrm_sib_rip_relative(
    comptime Reg: type,
    writer: *Writer,
    reg: Reg,
    disp: RipRelativeMemory,
) EncodingError!usize {
    var written: usize = 0;

    // Compute components
    const mod = 0b00; // Register addressing mode
    const reg3: u3 = compute_reg3(Reg, reg);
    const rm3 = 0b101; // RIP-relative addressing mode
    const modrm_byte = modrm(mod, reg3, rm3);

    // Compute disp32
    const disp32: [@sizeOf(RipRelativeMemory)]u8 = extractBits(RipRelativeMemory, disp);

    // Write ModR/M and disp32
    written += 1;
    writer.writeByte(modrm_byte) catch {
        return EncodingError.WriterError;
    };
    written += @sizeOf(RipRelativeMemory);
    writer.writeAll(&disp32) catch {
        return EncodingError.WriterError;
    };

    return written;
}

fn emit_modrm_sib_base_index(
    comptime Reg: type,
    comptime Mem: type,
    writer: *Writer,
    reg: Reg,
    mem: Mem,
) EncodingError!usize {
    const DISP0: u2 = 0b00;
    const DISP8: u2 = 0b01;
    const DISP32: u2 = 0b10;
    const NO_BASE: u3 = 0b101;
    const SIB_PRESENT: u3 = 0b100;

    var written: usize = 0;

    const base_low3: u3 = if (mem.base) |base| base.reg_low3() else NO_BASE;

    const has_base = mem.base != null;
    const has_index = mem.index != null;

    // Special case: if there's no base register, we must use disp32 addressing mode.
    const force_disp32 = !has_base;

    // Special case: no-base/no-index in base-index addressing must use SIB for absolute disp32.
    // Otherwise mod=00 rm=101 is interpreted as IP-relative (RIP/EIP depending on addr-size).
    const force_sib_abs_disp32 = !has_base and !has_index;

    const need_sib = mem.base_requires_sib() or has_index or force_sib_abs_disp32;

    // Special case: mod=00 with rm=101 (no base) is not allowed for memory operands,
    // because it encodes RIP-relative addressing.
    const base_is_mod00_forbidden = has_base and base_low3 == NO_BASE;

    var mod: u2 = undefined;
    if (force_disp32) {
        mod = DISP0;
    } else if (mem.disp == 0 and !base_is_mod00_forbidden) {
        mod = DISP0;
    } else if (mem.disp >= -128 and mem.disp <= 127) {
        mod = DISP8;
    } else {
        mod = DISP32;
    }

    const reg3: u3 = compute_reg3(Reg, reg);
    const rm3: u3 = if (need_sib) SIB_PRESENT else if (has_base) base_low3 else NO_BASE;

    const modrm_byte = modrm(mod, reg3, rm3);

    // Write ModR/M byte
    written += 1;
    writer.writeByte(modrm_byte) catch {
        return EncodingError.WriterError;
    };

    // Write SIB byte if needed
    if (need_sib) {
        const scale_bits: u8 = if (mem.index) |idx| @intFromEnum(idx.scale) else 0;
        const index_bits: u8 = if (mem.index) |idx| idx.reg.reg_low3() else 0b100; // No index
        const base_bits: u8 = if (has_base) base_low3 else NO_BASE; // No base => disp32

        const sib_byte = sib(scale_bits, index_bits, base_bits);

        written += 1;
        writer.writeByte(sib_byte) catch {
            return EncodingError.WriterError;
        };
    }

    // Emit displacement bytes.
    if (force_disp32 or mod == DISP32) {
        const disp32: [4]u8 = extractBits(i32, mem.disp);
        written += 4;
        writer.writeAll(&disp32) catch {
            return EncodingError.WriterError;
        };
    } else if (mod == DISP8) {
        const disp8: i8 = @intCast(mem.disp);
        const disp8_bits: [1]u8 = extractBits(i8, disp8);
        written += 1;
        writer.writeAll(&disp8_bits) catch {
            return EncodingError.WriterError;
        };
    }

    return written;
}

inline fn compute_reg3(comptime Reg: type, reg: Reg) u3 {
    var reg3: u3 = undefined;

    if (Reg != void) {
        ensure_index_reg(Reg);
        reg3 = reg.reg_low3();
    } else {
        reg3 = 0; // Default to 0 if Reg is void
    }

    return reg3;
}

pub fn is_memory_register(comptime T: type) bool {
    comptime {
        const typeInfo = @typeInfo(T);

        switch (typeInfo) {
            .@"union" => |unionInfo| {
                var foundField: u2 = 0;

                for (unionInfo.fields) |field| {
                    if (std.mem.eql(u8, field.name, "reg")) {
                        if (is_index_register(field.type)) {
                            foundField |= 0b01;
                        } else {
                            return false; // The 'reg' field exists but is not a valid index register type
                        }
                    } else if (std.mem.eql(u8, field.name, "mem")) {
                        if (is_memory(field.type)) {
                            foundField |= 0b10;
                        } else {
                            return false; // The 'mem' field exists but is not of type Memory
                        }
                    }
                }

                if (foundField == 0b11) {
                    return true;
                } else {
                    return false;
                }
            },
            else => {
                return false;
            },
        }
    }
}

pub fn is_index_register(comptime T: type) bool {
    comptime {
        const typeInfo = @typeInfo(T);

        switch (typeInfo) {
            .@"enum" => |enumInfo| {
                var foundMethod: u4 = 0;

                for (enumInfo.decls) |field| {
                    if (std.mem.eql(u8, field.name, "reg_low3")) {
                        foundMethod |= 0b0001;
                    } else if (std.mem.eql(u8, field.name, "is_extended")) {
                        foundMethod |= 0b0010;
                    } else if (std.mem.eql(u8, field.name, "need_rex")) {
                        foundMethod |= 0b0100;
                    } else if (std.mem.eql(u8, field.name, "is_high_register")) {
                        foundMethod |= 0b1000;
                    }
                }
                // Check if all required flags are set
                return foundMethod == 0b1111;
            },
            else => {
                return false;
            },
        }
    }
}

pub fn is_memory(comptime T: type) bool {
    comptime {
        return T == Memory;
    }
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
        var memType = Mem;
        if (is_memory_register(Mem)) {
            memType = fetch_index_register(Mem);
        }

        if (memType != Reg) {
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
