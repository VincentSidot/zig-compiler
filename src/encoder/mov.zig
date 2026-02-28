//! Encoder module for encoding assembly instructions.
//! This module provides a simple interface for encoding MOV instructions
//! This is built from https://www.felixcloutier.com/x86/mov

const std = @import("std");
const builtin = @import("builtin");

const log = if (builtin.is_test)
    // Downgrade `err` to `warn` for tests.
    // Zig fails any test that does `log.err`, but we want to test those code paths here.
    struct {
        const base = std.log.scoped(.clock);
        const err = warn;
        const warn = base.warn;
        const info = base.info;
        const debug = base.debug;
    }
else
    std.log.scoped(.clock);

const error_file = @import("error.zig");
const EncodingError = error_file.EncodingError;

const arithmetic = @import("arithmetic.zig");
const extractBits = arithmetic.extractBits;

const register = @import("reg.zig");

const Register64 = register.RegisterIndex_64;
const Register32 = register.RegisterIndex_32;
const Register16 = register.RegisterIndex_16;
const Register8 = register.RegisterIndex_8;

const RegisterMemory64 = register.RegisterMemory_64;
const RegisterMemory32 = register.RegisterMemory_32;
const RegisterMemory16 = register.RegisterMemory_16;
const RegisterMemory8 = register.RegisterMemory_8;

const is_memory_register = register.is_memory_register;
const fetch_index_register = register.fetch_index_register;
const emit_modrm_sib = register.emit_modrm_sib;
const ensure_matching_reg = register.ensure_matching_reg;

const Register16_LegacyPrefix = 0x66;

/// REX prefix encoding for x86-64 instructions.
/// in x86-64 assembly.
/// w: 64-bit operand size
/// x: index field extension
/// r: reg field extension
/// b: r/m field extension
fn rex_bytes(w: bool, r: bool, x: bool, b: bool) u8 {
    var v: u8 = 0x40;
    if (w) v |= 0b1000;
    if (r) v |= 0b0100;
    if (x) v |= 0b0010;
    if (b) v |= 0b0001;
    return v;
}

fn movimm_byte(opcode: u8, reg_low3: u8) u8 {
    // MOV r8, imm8 opcodes are 0xB0 + reg_low3
    // MOV r16/32/64, imm16/32/64 opcodes are 0xB8 + reg_low3
    return opcode | (reg_low3 & 0x7);
}

fn fits_signext32_range(value: u64) bool {
    const MAX_POS: u64 = 0x0000_0000_7FFF_FFFF; // 2^31 - 1
    const MIN_NEG: u64 = 0xFFFF_FFFF_8000_0000; // -2^31 in two's complement

    return value <= MAX_POS or value >= MIN_NEG;
}

const MOV_OPCODE = struct {
    const MOV_RM8_R8: u8 = 0x88;
    const MOV_RM16_R16: u8 = 0x89;
    const MOV_RM32_R32: u8 = 0x89;
    const MOV_RM64_R64: u8 = 0x89;

    const MOV_R8_RM8: u8 = 0x8A;
    const MOV_R16_RM16: u8 = 0x8B;
    const MOV_R32_RM32: u8 = 0x8B;
    const MOV_R64_RM64: u8 = 0x8B;

    const MOV_R8_IMM8: u8 = 0xB0;
    const MOV_R16_IMM16: u8 = 0xB8;
    const MOV_R32_IMM32: u8 = 0xB8;
    const MOV_R64_IMM64: u8 = 0xB8;

    const MOV_RM8_IMM8: u8 = 0xC6;
    const MOV_RM16_IMM16: u8 = 0xC7;
    const MOV_RM32_IMM32: u8 = 0xC7;
    const MOV_RM64_IMM64: u8 = 0xC7;
};

const Writer = std.io.Writer;

fn factory_mov(
    comptime Dst: type,
    comptime Src: type,
    comptime opcode: u8,
) fn (writer: *Writer, dest: Dst, source: Src) EncodingError!usize {
    const dest_is_rm = comptime is_memory_register(Dst);

    const Reg = comptime if (dest_is_rm) Src else Dst;
    const Mem = comptime if (dest_is_rm) Dst else Src;

    ensure_matching_reg(Mem, Reg);

    const is_16bit = Reg == Register16;
    const is_64bit = Reg == Register64;

    const factory = struct {
        fn _inner(writer: *Writer, dest: Dst, source: Src) EncodingError!usize {
            var writen: usize = 0;

            if (source.is_high_register() and dest.need_rex()) {
                if (!builtin.is_test) {
                    log.err("Moving from high register to register that needs REX prefix is invalid", .{});
                }
                return error.InvalidOperand;
            } else if (source.need_rex() and dest.is_high_register()) {
                if (!builtin.is_test) {
                    log.err("Moving from register that needs REX prefix to high register is invalid", .{});
                }
                return error.InvalidOperand;
            }

            var reg: Reg = undefined;
            var rm: Mem = undefined;

            if (dest_is_rm) {
                reg = source;
                rm = dest;
            } else {
                reg = dest;
                rm = source;
            }

            if (is_16bit) {
                // For 16-bit registers, we need to add legacy prefix
                writen += 1;
                writer.writeByte(Register16_LegacyPrefix) catch {
                    return EncodingError.WriterError;
                };
            }

            if (source.need_rex() or dest.need_rex()) {
                const rex = rex_bytes(
                    is_64bit, // w bit is set for 64-bit operand size
                    reg.is_extended(),
                    rm.rex_x(),
                    rm.rex_b(),
                );

                writen += 1;
                writer.writeByte(rex) catch {
                    return EncodingError.WriterError;
                };
            }

            writen += 1;
            writer.writeByte(opcode) catch {
                return EncodingError.WriterError;
            };

            writen += try emit_modrm_sib(
                Reg,
                Mem,
                writer,
                reg,
                rm,
            );

            return writen;
        }
    };

    return factory._inner;
}

fn factory_mov_imm(comptime Reg: type, comptime Imm: type, comptime opcode: u8) fn (writer: *Writer, dest: Reg, source: Imm) EncodingError!usize {
    const dest_is_rm = comptime is_memory_register(Reg);

    const is_16bit = comptime blk: {
        if (is_memory_register(Reg)) {
            break :blk fetch_index_register(Reg) == Register16;
        } else {
            break :blk Reg == Register16;
        }
    };

    const is_64bit = comptime blk: {
        if (is_memory_register(Reg)) {
            break :blk fetch_index_register(Reg) == Register64;
        } else {
            break :blk Reg == Register64;
        }
    };

    const factory = struct {
        fn _inner(writer: *Writer, dest: Reg, source: Imm) EncodingError!usize {
            var writen: usize = 0;

            if (is_16bit) {
                // For 16-bit registers, we need to add legacy prefix
                writen += 1;
                writer.writeByte(Register16_LegacyPrefix) catch {
                    return EncodingError.WriterError;
                };
            }

            if (dest.need_rex() or Reg == RegisterMemory64) {
                const rex_x = if (dest_is_rm) dest.rex_x() else false;
                const rex_b = if (dest_is_rm) dest.rex_b() else dest.is_extended();

                const rex = rex_bytes(
                    is_64bit, // w bit is set for 64-bit operand size
                    false,
                    rex_x,
                    rex_b,
                );

                writen += 1;
                writer.writeByte(rex) catch {
                    return EncodingError.WriterError;
                };
            }

            if (dest_is_rm) {
                writen += 1;
                writer.writeByte(opcode) catch {
                    return EncodingError.WriterError;
                };

                writen += try emit_modrm_sib(
                    void,
                    Reg,
                    writer,
                    undefined,
                    dest,
                );
            } else {
                const movimm: u8 = movimm_byte(opcode, dest.reg_low3());

                writen += 1;
                writer.writeByte(movimm) catch {
                    return EncodingError.WriterError;
                };
            }

            // Write the immediate value in little-endian format
            // Here Src is the type of the immediate value.
            writen += @sizeOf(Imm);
            const bytes = extractBits(Imm, source);
            writer.writeAll(&bytes) catch {
                return EncodingError.WriterError;
            };

            return writen;
        }
    };

    return factory._inner;
}

pub const mov = struct {
    // This won't compile for now - it's okay since we are working on the factory logic for now.

    pub const rm8_r8 = factory_mov(
        RegisterMemory8,
        Register8,
        MOV_OPCODE.MOV_RM8_R8,
    );
    pub const r8_rm8 = factory_mov(Register8, RegisterMemory8, MOV_OPCODE.MOV_R8_RM8);
    pub const rm8_imm8 = factory_mov_imm(RegisterMemory8, u8, MOV_OPCODE.MOV_RM8_IMM8);
    pub const r8_imm8 = factory_mov_imm(Register8, u8, MOV_OPCODE.MOV_R8_IMM8);

    pub const rm16_r16 = factory_mov(RegisterMemory16, Register16, MOV_OPCODE.MOV_RM16_R16);
    pub const r16_rm16 = factory_mov(Register16, RegisterMemory16, MOV_OPCODE.MOV_R16_RM16);
    pub const rm16_imm16 = factory_mov_imm(RegisterMemory16, u16, MOV_OPCODE.MOV_RM16_IMM16);
    pub const r16_imm16 = factory_mov_imm(Register16, u16, MOV_OPCODE.MOV_R16_IMM16);

    pub const rm32_r32 = factory_mov(RegisterMemory32, Register32, MOV_OPCODE.MOV_RM32_R32);
    pub const r32_rm32 = factory_mov(Register32, RegisterMemory32, MOV_OPCODE.MOV_R32_RM32);
    pub const rm32_imm32 = factory_mov_imm(RegisterMemory32, u32, MOV_OPCODE.MOV_RM32_IMM32);
    pub const r32_imm32 = factory_mov_imm(Register32, u32, MOV_OPCODE.MOV_R32_IMM32);

    pub const rm64_r64 = factory_mov(RegisterMemory64, Register64, MOV_OPCODE.MOV_RM64_R64);
    pub const r64_rm64 = factory_mov(Register64, RegisterMemory64, MOV_OPCODE.MOV_R64_RM64);
    pub const rm64_imm32 = factory_mov_imm(RegisterMemory64, u32, MOV_OPCODE.MOV_RM64_IMM64);
    pub const r64_imm64 = factory_mov_imm(Register64, u64, MOV_OPCODE.MOV_R64_IMM64);

    pub fn r64_imm64_auto(writer: *Writer, dest: Register64, source: u64) EncodingError!usize {
        if (fits_signext32_range(source)) {
            var converted: u32 = undefined;

            if (source <= 0x7FFF_FFFF) {
                converted = @intCast(source);
            } else {
                // Convert to two's complement negative value
                const shifted = source - 0x1_0000_0000;
                converted = @intCast(shifted & 0xFFFF_FFFF);
            }

            return mov.rm64_imm32(writer, RegisterMemory64{ .reg = dest }, converted);
        } else {
            return mov.r64_imm64(writer, dest, source);
        }
    }
};
