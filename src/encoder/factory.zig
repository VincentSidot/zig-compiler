const std = @import("std");

const error_file = @import("error.zig");
const EncodingError = error_file.EncodingError;

const helper = @import("helper.zig");
const extractBits = helper.extractBits;

const register = @import("reg.zig");

const Register64 = register.RegisterIndex_64;
const Register16 = register.RegisterIndex_16;

const is_memory_register = register.is_memory_register;
const fetch_index_register = register.fetch_index_register;
const emit_modrm_sib = register.emit_modrm_sib;
const ensure_matching_reg = register.ensure_matching_reg;

const BIT32_ADDRESSING_PREFIX = register.BIT32_ADDRESSING_PREFIX;
const Register16_LegacyPrefix = 0x66;

const Writer = std.Io.Writer;

pub const ImmediateMode = enum {
    modrm_group,
    opcode_plus_reg,
};

pub const ImmediateConfig = struct {
    mode: ImmediateMode,
    opcode: u8,
    modrm_reg: u3 = 0,
};

/// REX prefix encoding for x86-64 instructions.
/// w: 64-bit operand size
/// x: index field extension
/// r: reg field extension
/// b: r/m field extension
pub fn rex_bytes(w: bool, r: bool, x: bool, b: bool) u8 {
    var v: u8 = 0x40;
    if (w) v |= 0b1000;
    if (r) v |= 0b0100;
    if (x) v |= 0b0010;
    if (b) v |= 0b0001;
    return v;
}

pub fn factory_op(
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
            var written: usize = 0;

            // 8-bit high registers are not encodable with any REX prefix.
            if (source.is_high_register() and dest.need_rex()) {
                return error.InvalidOperand;
            } else if (source.need_rex() and dest.is_high_register()) {
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

            const is_32bit_mem = rm.is_memory32();

            if (is_16bit) {
                written += 1;
                writer.writeByte(Register16_LegacyPrefix) catch {
                    return EncodingError.WriterError;
                };
            }

            if (is_32bit_mem) {
                written += 1;
                writer.writeByte(BIT32_ADDRESSING_PREFIX) catch {
                    return EncodingError.WriterError;
                };
            }

            if (source.need_rex() or dest.need_rex()) {
                const rex = rex_bytes(
                    is_64bit,
                    reg.is_extended(),
                    rm.rex_x(),
                    rm.rex_b(),
                );

                written += 1;
                writer.writeByte(rex) catch {
                    return EncodingError.WriterError;
                };
            }

            written += 1;
            writer.writeByte(opcode) catch {
                return EncodingError.WriterError;
            };

            written += try emit_modrm_sib(
                Reg,
                Mem,
                writer,
                reg,
                rm,
            );

            return written;
        }
    };

    return factory._inner;
}

pub fn factory_imm(
    comptime Dest: type,
    comptime Imm: type,
    comptime config: ImmediateConfig,
) fn (writer: *Writer, dest: Dest, source: Imm) EncodingError!usize {
    const dest_is_rm = comptime is_memory_register(Dest);

    const is_16bit = comptime blk: {
        if (dest_is_rm) {
            break :blk fetch_index_register(Dest) == Register16;
        } else {
            break :blk Dest == Register16;
        }
    };

    const is_64bit = comptime blk: {
        if (dest_is_rm) {
            break :blk fetch_index_register(Dest) == Register64;
        } else {
            break :blk Dest == Register64;
        }
    };

    const factory = struct {
        fn _inner(writer: *Writer, dest: Dest, source: Imm) EncodingError!usize {
            var written: usize = 0;
            const is_32bit_mem = if (dest_is_rm) dest.is_memory32() else false;

            if (is_16bit) {
                written += 1;
                writer.writeByte(Register16_LegacyPrefix) catch {
                    return EncodingError.WriterError;
                };
            }

            if (is_32bit_mem) {
                written += 1;
                writer.writeByte(BIT32_ADDRESSING_PREFIX) catch {
                    return EncodingError.WriterError;
                };
            }

            if (dest.need_rex() or (dest_is_rm and is_64bit)) {
                const rex_x = if (dest_is_rm) dest.rex_x() else false;
                const rex_b = if (dest_is_rm) dest.rex_b() else dest.is_extended();

                const rex = rex_bytes(
                    is_64bit,
                    false,
                    rex_x,
                    rex_b,
                );

                written += 1;
                writer.writeByte(rex) catch {
                    return EncodingError.WriterError;
                };
            }

            switch (config.mode) {
                .modrm_group => {
                    if (!dest_is_rm) {
                        @compileError("factory_imm(.modrm_group) requires a RegMem destination type");
                    }

                    written += 1;
                    writer.writeByte(config.opcode) catch {
                        return EncodingError.WriterError;
                    };

                    written += try emit_modrm_sib(
                        u3,
                        Dest,
                        writer,
                        config.modrm_reg,
                        dest,
                    );
                },
                .opcode_plus_reg => {
                    if (dest_is_rm) {
                        @compileError("factory_imm(.opcode_plus_reg) requires a register destination type");
                    }

                    const opcode = config.opcode | (dest.reg_low3() & 0x7);
                    written += 1;
                    writer.writeByte(opcode) catch {
                        return EncodingError.WriterError;
                    };
                },
            }

            written += @sizeOf(Imm);
            const bytes = extractBits(Imm, source);
            writer.writeAll(&bytes) catch {
                return EncodingError.WriterError;
            };

            return written;
        }
    };

    return factory._inner;
}
