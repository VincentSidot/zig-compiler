const std = @import("std");
const encoder = @import("../encoder/lib.zig");
const encoder_reg = @import("../encoder/reg.zig");

pub const Label = struct {
    index: usize,
};

pub const Condition = encoder.opcode.jcc.Condition;

pub const BranchTarget = union(enum) {
    label: Label,
    rel: i32,
    reg: Arg,
    mem: Memory,
};

pub const MemSize = enum {
    byte,
    word,
    dword,
    qword,
};

pub const Immediate = union(enum) {
    signed: i64,
    unsigned: u64,
    raw8: u8,
    raw16: u16,
    raw32: u32,
    raw64: u64,

    pub fn encode8(self: Immediate) !u8 {
        return switch (self) {
            .signed => |v| {
                const x = std.math.cast(i8, v) orelse return error.Overflow;
                return @bitCast(x);
            },
            .unsigned => |v| std.math.cast(u8, v) orelse return error.Overflow,
            .raw8 => |v| v,
            else => error.InvalidOperand,
        };
    }

    pub fn encode16(self: Immediate) !u16 {
        return switch (self) {
            .signed => |v| {
                const x = std.math.cast(i16, v) orelse return error.Overflow;
                return @bitCast(x);
            },
            .unsigned => |v| std.math.cast(u16, v) orelse return error.Overflow,
            .raw16 => |v| v,
            else => error.InvalidOperand,
        };
    }

    pub fn encode32(self: Immediate) !u32 {
        return switch (self) {
            .signed => |v| {
                const x = std.math.cast(i32, v) orelse return error.Overflow;
                return @bitCast(x);
            },
            .unsigned => |v| std.math.cast(u32, v) orelse return error.Overflow,
            .raw32 => |v| v,
            else => error.InvalidOperand,
        };
    }

    pub fn encode64(self: Immediate) !u64 {
        return switch (self) {
            .signed => |v| @bitCast(v),
            .unsigned => |v| v,
            .raw64 => |v| v,
            else => error.InvalidOperand,
        };
    }

    pub fn encodePush8(self: Immediate) !i8 {
        return switch (self) {
            .signed => |v| std.math.cast(i8, v) orelse return error.Overflow,
            .unsigned => |v| std.math.cast(i8, v) orelse return error.Overflow,
            .raw8 => |v| @bitCast(v),
            else => error.InvalidOperand,
        };
    }
};

pub const Arg = union(enum) {
    rax,
    eax,
    ax,
    ah,
    al,
    rbx,
    ebx,
    bx,
    bh,
    bl,
    rcx,
    ecx,
    cx,
    ch,
    cl,
    rdx,
    edx,
    dx,
    dh,
    dl,
    rsi,
    esi,
    si,
    sil,
    rdi,
    edi,
    di,
    dil,
    rbp,
    ebp,
    bp,
    bpl,
    rsp,
    esp,
    sp,
    spl,
    r8,
    r8d,
    r8w,
    r8b,
    r9,
    r9d,
    r9w,
    r9b,
    r10,
    r10d,
    r10w,
    r10b,
    r11,
    r11d,
    r11w,
    r11b,
    r12,
    r12d,
    r12w,
    r12b,
    r13,
    r13d,
    r13w,
    r13b,
    r14,
    r14d,
    r14w,
    r14b,
    r15,
    r15d,
    r15w,
    r15b,
    mem: Memory,
    imm: Immediate,

    pub fn is_register64(self: Arg) bool {
        return switch (self) {
            .rax, .rbx, .rcx, .rdx, .rsi, .rdi, .rbp, .rsp, .r8, .r9, .r10, .r11, .r12, .r13, .r14, .r15 => true,
            else => false,
        };
    }

    pub fn is_register32(self: Arg) bool {
        return switch (self) {
            .eax, .ebx, .ecx, .edx, .esi, .edi, .ebp, .esp, .r8d, .r9d, .r10d, .r11d, .r12d, .r13d, .r14d, .r15d => true,
            else => false,
        };
    }

    pub fn is_register16(self: Arg) bool {
        return switch (self) {
            .ax, .bx, .cx, .dx, .si, .di, .bp, .sp, .r8w, .r9w, .r10w, .r11w, .r12w, .r13w, .r14w, .r15w => true,
            else => false,
        };
    }

    pub fn is_register8(self: Arg) bool {
        return switch (self) {
            .al, .ah, .bl, .bh, .cl, .ch, .dl, .dh, .sil, .dil, .bpl, .spl, .r8b, .r9b, .r10b, .r11b, .r12b, .r13b, .r14b, .r15b => true,
            else => false,
        };
    }

    pub fn is_register(self: Arg) bool {
        return self.is_register64() or self.is_register32() or self.is_register16() or self.is_register8();
    }

    pub fn register(self: Arg) ?RegKind {
        if (self.is_register64()) return .Reg64;
        if (self.is_register32()) return .Reg32;
        if (self.is_register16()) return .Reg16;
        if (self.is_register8()) return .Reg8;
        return null;
    }

    pub fn is_memory(self: Arg) bool {
        return switch (self) {
            .mem => true,
            else => false,
        };
    }

    pub fn is_immediate(self: Arg) bool {
        return switch (self) {
            .imm => true,
            else => false,
        };
    }

    pub fn as_reg8(self: Arg) ?encoder.RegisterIndex_8 {
        return switch (self) {
            .al => .AL,
            .ah => .AH,
            .bl => .BL,
            .bh => .BH,
            .cl => .CL,
            .ch => .CH,
            .dl => .DL,
            .dh => .DH,
            .sil => .SIL,
            .dil => .DIL,
            .bpl => .BPL,
            .spl => .SPL,
            .r8b => .R8B,
            .r9b => .R9B,
            .r10b => .R10B,
            .r11b => .R11B,
            .r12b => .R12B,
            .r13b => .R13B,
            .r14b => .R14B,
            .r15b => .R15B,
            else => null,
        };
    }

    pub fn as_reg16(self: Arg) ?encoder.RegisterIndex_16 {
        return switch (self) {
            .ax => .AX,
            .bx => .BX,
            .cx => .CX,
            .dx => .DX,
            .si => .SI,
            .di => .DI,
            .bp => .BP,
            .sp => .SP,
            .r8w => .R8W,
            .r9w => .R9W,
            .r10w => .R10W,
            .r11w => .R11W,
            .r12w => .R12W,
            .r13w => .R13W,
            .r14w => .R14W,
            .r15w => .R15W,
            else => null,
        };
    }

    pub fn as_reg32(self: Arg) ?encoder.RegisterIndex_32 {
        return switch (self) {
            .eax => .EAX,
            .ebx => .EBX,
            .ecx => .ECX,
            .edx => .EDX,
            .esi => .ESI,
            .edi => .EDI,
            .ebp => .EBP,
            .esp => .ESP,
            .r8d => .R8D,
            .r9d => .R9D,
            .r10d => .R10D,
            .r11d => .R11D,
            .r12d => .R12D,
            .r13d => .R13D,
            .r14d => .R14D,
            .r15d => .R15D,
            else => null,
        };
    }

    pub fn as_reg64(self: Arg) ?encoder.RegisterIndex_64 {
        return switch (self) {
            .rax => .RAX,
            .rbx => .RBX,
            .rcx => .RCX,
            .rdx => .RDX,
            .rsi => .RSI,
            .rdi => .RDI,
            .rbp => .RBP,
            .rsp => .RSP,
            .r8 => .R8,
            .r9 => .R9,
            .r10 => .R10,
            .r11 => .R11,
            .r12 => .R12,
            .r13 => .R13,
            .r14 => .R14,
            .r15 => .R15,
            else => null,
        };
    }

    pub fn as_mem8(self: Arg) !?encoder.RegisterMemory_8 {
        return switch (self) {
            .mem => |m| if (m.size == .byte) try m.encoderMem(encoder.RegisterMemory_8) else error.InvalidOperand,
            else => null,
        };
    }

    pub fn as_mem16(self: Arg) !?encoder.RegisterMemory_16 {
        return switch (self) {
            .mem => |m| if (m.size == .word) try m.encoderMem(encoder.RegisterMemory_16) else error.InvalidOperand,
            else => null,
        };
    }

    pub fn as_mem32(self: Arg) !?encoder.RegisterMemory_32 {
        return switch (self) {
            .mem => |m| if (m.size == .dword) try m.encoderMem(encoder.RegisterMemory_32) else error.InvalidOperand,
            else => null,
        };
    }

    pub fn as_mem64(self: Arg) !?encoder.RegisterMemory_64 {
        return switch (self) {
            .mem => |m| if (m.size == .qword) try m.encoderMem(encoder.RegisterMemory_64) else error.InvalidOperand,
            else => null,
        };
    }

    pub fn as_imm8(self: Arg) !?u8 {
        return switch (self) {
            .imm => |v| try v.encode8(),
            else => null,
        };
    }

    pub fn as_imm16(self: Arg) !?u16 {
        return switch (self) {
            .imm => |v| try v.encode16(),
            else => null,
        };
    }

    pub fn as_imm32(self: Arg) !?u32 {
        return switch (self) {
            .imm => |v| try v.encode32(),
            else => null,
        };
    }

    pub fn as_imm64(self: Arg) !?u64 {
        return switch (self) {
            .imm => |v| try v.encode64(),
            else => null,
        };
    }

    pub fn immediate(value: anytype) Arg {
        return .{ .imm = .{ .signed = @intCast(value) } };
    }

    pub fn unsigned(value: anytype) Arg {
        return .{ .imm = .{ .unsigned = @intCast(value) } };
    }

    pub fn raw8(value: u8) Arg {
        return .{ .imm = .{ .raw8 = value } };
    }

    pub fn raw16(value: u16) Arg {
        return .{ .imm = .{ .raw16 = value } };
    }

    pub fn raw32(value: u32) Arg {
        return .{ .imm = .{ .raw32 = value } };
    }

    pub fn raw64(value: u64) Arg {
        return .{ .imm = .{ .raw64 = value } };
    }
};

pub const Memory = struct {
    size: MemSize,
    reg: RegM,
    disp: i64 = 0,
    index: ?Index = null,

    pub fn validateIndex(self: Memory) !void {
        if (self.index) |index| {
            if (index.reg.is_register32() != self.reg.is_register32()) {
                return error.InvalidIndexRegister;
            }
        }
    }

    pub fn is_register32(self: Memory) !bool {
        try self.validateIndex();
        return self.reg.is_register32();
    }

    pub fn is_register64(self: Memory) !bool {
        try self.validateIndex();
        return self.reg.is_register64();
    }

    fn encoderMem(self: Memory, comptime T: type) !T {
        try self.validateIndex();

        const disp = std.math.cast(i32, self.disp) orelse return error.Overflow;

        if (try self.is_register32()) {
            return T{ .mem = .{ .baseIndex32 = .{
                .base = self.reg.as_reg32(),
                .index = if (self.index) |idx| .{ .reg = idx.reg.as_reg32() orelse return error.InvalidOperand, .scale = idx.scale.encoderScale() } else null,
                .disp = disp,
            } } };
        }

        return T{ .mem = .{ .baseIndex64 = .{
            .base = self.reg.as_reg64(),
            .index = if (self.index) |idx| .{ .reg = idx.reg.as_reg64() orelse return error.InvalidOperand, .scale = idx.scale.encoderScale() } else null,
            .disp = disp,
        } } };
    }
};

pub const RegKind = enum {
    Reg64,
    Reg32,
    Reg16,
    Reg8,
};

pub const RegM = enum {
    rax,
    eax,
    rbx,
    ebx,
    rcx,
    ecx,
    rdx,
    edx,
    rsi,
    esi,
    rdi,
    edi,
    rbp,
    ebp,
    rsp,
    esp,
    r8,
    r8d,
    r9,
    r9d,
    r10,
    r10d,
    r11,
    r11d,
    r12,
    r12d,
    r13,
    r13d,
    r14,
    r14d,
    r15,
    r15d,

    pub fn is_register32(self: RegM) bool {
        return switch (self) {
            .eax, .ebx, .ecx, .edx, .esi, .edi, .ebp, .esp, .r8d, .r9d, .r10d, .r11d, .r12d, .r13d, .r14d, .r15d => true,
            else => false,
        };
    }

    pub fn is_register64(self: RegM) bool {
        return switch (self) {
            .rax, .rbx, .rcx, .rdx, .rsi, .rdi, .rbp, .rsp, .r8, .r9, .r10, .r11, .r12, .r13, .r14, .r15 => true,
            else => false,
        };
    }

    fn as_reg32(self: RegM) ?encoder.RegisterIndex_32 {
        return switch (self) {
            .eax => .EAX,
            .ebx => .EBX,
            .ecx => .ECX,
            .edx => .EDX,
            .esi => .ESI,
            .edi => .EDI,
            .ebp => .EBP,
            .esp => .ESP,
            .r8d => .R8D,
            .r9d => .R9D,
            .r10d => .R10D,
            .r11d => .R11D,
            .r12d => .R12D,
            .r13d => .R13D,
            .r14d => .R14D,
            .r15d => .R15D,
            else => null,
        };
    }

    fn as_reg64(self: RegM) ?encoder.RegisterIndex_64 {
        return switch (self) {
            .rax => .RAX,
            .rbx => .RBX,
            .rcx => .RCX,
            .rdx => .RDX,
            .rsi => .RSI,
            .rdi => .RDI,
            .rbp => .RBP,
            .rsp => .RSP,
            .r8 => .R8,
            .r9 => .R9,
            .r10 => .R10,
            .r11 => .R11,
            .r12 => .R12,
            .r13 => .R13,
            .r14 => .R14,
            .r15 => .R15,
            else => null,
        };
    }
};

pub const Index = struct {
    reg: RegM,
    scale: Scale = .x1,
};

pub const Scale = enum {
    x1,
    x2,
    x4,
    x8,

    fn encoderScale(self: Scale) encoder_reg.Scale {
        return switch (self) {
            .x1 => .x1,
            .x2 => .x2,
            .x4 => .x4,
            .x8 => .x8,
        };
    }
};
