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

const lib = @import("lib.zig");
const EncodingError = lib.EncodingError;

const register = @import("reg.zig");
const Register64 = register.RegisterIndex_64;
const Register32 = register.RegisterIndex_32;
const Register16 = register.RegisterIndex_16;
const Register8 = register.RegisterIndex_8;

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

/// ModRM byte encoding:
/// mod: addressing mode (2 bits)
/// reg: register operand (3 bits)
/// rm: r/m operand (3 bits)
fn modrm_byte(mod: u8, reg3: u8, rm3: u8) u8 {
    // mod (2 bits) in bits 7..6
    // reg (3 bits) in bits 5..3
    // rm  (3 bits) in bits 2..0
    return ((mod & 0x3) << 6) | ((reg3 & 0x7) << 3) | (rm3 & 0x7);
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

fn factory_mov(comptime R: type, comptime opcode: u8, comptime is_dest_rm: bool) fn (writer: *Writer, dest: R, source: R) EncodingError!usize {
    const factory = struct {
        fn _inner(writer: *Writer, dest: R, source: R) EncodingError!usize {
            var writen: usize = 0;

            if (source.is_high_register() and dest.need_rex()) {
                log.err("Moving from high register to register that needs REX prefix is invalid", .{});
                return error.InvalidOperand;
            } else if (source.need_rex() and dest.is_high_register()) {
                log.err("Moving from register that needs REX prefix to high register is invalid", .{});
                return error.InvalidOperand;
            }

            if (R == Register16) {
                // For 16-bit registers, we need to add legacy prefix
                writen += 1;
                writer.writeByte(Register16_LegacyPrefix) catch {
                    return EncodingError.WriterError;
                };
            }

            var reg: R = undefined;
            var rm: R = undefined;

            if (is_dest_rm) {
                reg = source;
                rm = dest;
            } else {
                reg = dest;
                rm = source;
            }

            if (source.need_rex() or dest.need_rex()) {
                const rex = rex_bytes(
                    R == Register64, // w bit is set for 64-bit operand size
                    reg.is_extended(),
                    false, // x bit is not used for MOV reg-reg
                    rm.is_extended(),
                );

                writen += 1;
                writer.writeByte(rex) catch {
                    return EncodingError.WriterError;
                };
            }

            const modrm = modrm_byte(
                0b11,
                reg.reg_low3(),
                rm.reg_low3(),
            );

            writen += writer.write(&.{
                opcode,
                modrm,
            }) catch {
                return EncodingError.WriterError;
            };

            return writen;
        }
    };

    return factory._inner;
}

fn factory_mov_imm(comptime R: type, comptime T: type, comptime opcode: u8, comptime is_dest_rm: bool) fn (writer: *Writer, dest: R, source: T) EncodingError!usize {
    const factory = struct {
        fn _inner(writer: *Writer, dest: R, source: T) EncodingError!usize {
            var writen: usize = 0;

            if (R == Register16) {
                // For 16-bit registers, we need to add legacy prefix
                writen += 1;
                writer.writeByte(Register16_LegacyPrefix) catch {
                    return EncodingError.WriterError;
                };
            }

            if (dest.need_rex()) {
                const rex = rex_bytes(
                    R == Register64, // w bit is set for 64-bit operand size
                    false,
                    false,
                    dest.is_extended(),
                );

                writen += 1;
                writer.writeByte(rex) catch {
                    return EncodingError.WriterError;
                };
            }

            if (is_dest_rm) {
                const modrm = modrm_byte(
                    0b11,
                    0,
                    dest.reg_low3(),
                );

                writen += writer.write(&.{
                    opcode,
                    modrm,
                }) catch {
                    return EncodingError.WriterError;
                };
            } else {
                const movimm: u8 = movimm_byte(opcode, dest.reg_low3());

                writen += 1;
                writer.writeByte(movimm) catch {
                    return EncodingError.WriterError;
                };
            }

            // Write the immediate value in little-endian format
            writen += @sizeOf(T);
            writer.writeInt(T, source, .little) catch {
                return EncodingError.WriterError;
            };

            return writen;
        }
    };

    return factory._inner;
}

pub const mov = struct {
    pub const rm8_r8 = factory_mov(Register8, MOV_OPCODE.MOV_RM8_R8, true);
    pub const r8_rm8 = factory_mov(Register8, MOV_OPCODE.MOV_R8_RM8, false);
    pub const rm8_imm8 = factory_mov_imm(Register8, u8, MOV_OPCODE.MOV_RM8_IMM8, true);
    pub const r8_imm8 = factory_mov_imm(Register8, u8, MOV_OPCODE.MOV_R8_IMM8, false);

    pub const rm16_r16 = factory_mov(Register16, MOV_OPCODE.MOV_RM16_R16, true);
    pub const r16_rm16 = factory_mov(Register16, MOV_OPCODE.MOV_R16_RM16, false);
    pub const rm16_imm16 = factory_mov_imm(Register16, u16, MOV_OPCODE.MOV_RM16_IMM16, true);
    pub const r16_imm16 = factory_mov_imm(Register16, u16, MOV_OPCODE.MOV_R16_IMM16, false);

    pub const rm32_r32 = factory_mov(Register32, MOV_OPCODE.MOV_RM32_R32, true);
    pub const r32_rm32 = factory_mov(Register32, MOV_OPCODE.MOV_R32_RM32, false);
    pub const rm32_imm32 = factory_mov_imm(Register32, u32, MOV_OPCODE.MOV_RM32_IMM32, true);
    pub const r32_imm32 = factory_mov_imm(Register32, u32, MOV_OPCODE.MOV_R32_IMM32, false);

    pub const rm64_r64 = factory_mov(Register64, MOV_OPCODE.MOV_RM64_R64, true);
    pub const r64_rm64 = factory_mov(Register64, MOV_OPCODE.MOV_R64_RM64, false);
    pub const rm64_imm32 = factory_mov_imm(Register64, u32, MOV_OPCODE.MOV_RM64_IMM64, true);
    pub const r64_imm64 = factory_mov_imm(Register64, u64, MOV_OPCODE.MOV_R64_IMM64, false);

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

            return mov.rm64_imm32(writer, dest, converted);
        } else {
            return mov.r64_imm64(writer, dest, source);
        }
    }
};
