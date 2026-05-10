const std = @import("std");
const common = @import("common.zig");

const mov = common.mov;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_32 = common.RegisterIndex_32;
const RegisterMemory_32 = common.RegisterMemory_32;

fn validate(
    comptime Dest: type,
    comptime Src: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn (writer: *std.Io.Writer, dest: Dest, source: Src) EncodingError!usize,
    dest: Dest,
    source: Src,
) !void {
    try validate_impl(Dest, Src, name, expected, tested, dest, source);
}

test "MOV 32 bit registers" {
    try validate(RegisterMemory_32, RegisterIndex_32, "EAX, ECX", &.{ 0x89, 0xC8 }, mov.rm32_r32, .{ .reg = .EAX }, .ECX);
    try validate(RegisterMemory_32, RegisterIndex_32, "EBX, EDX", &.{ 0x89, 0xD3 }, mov.rm32_r32, .{ .reg = .EBX }, .EDX);
    try validate(RegisterMemory_32, RegisterIndex_32, "ESI, EDI", &.{ 0x89, 0xFE }, mov.rm32_r32, .{ .reg = .ESI }, .EDI);
    try validate(RegisterMemory_32, RegisterIndex_32, "EDI, EAX", &.{ 0x89, 0xC7 }, mov.rm32_r32, .{ .reg = .EDI }, .EAX);
}

test "MOV 32 bit registers extended" {
    try validate(RegisterMemory_32, RegisterIndex_32, "R8D, EAX", &.{ 0x41, 0x89, 0xC0 }, mov.rm32_r32, .{ .reg = .R8D }, .EAX);
    try validate(RegisterMemory_32, RegisterIndex_32, "EBX, R9D", &.{ 0x44, 0x89, 0xCB }, mov.rm32_r32, .{ .reg = .EBX }, .R9D);
    try validate(RegisterMemory_32, RegisterIndex_32, "R10D, R11D", &.{ 0x45, 0x89, 0xDA }, mov.rm32_r32, .{ .reg = .R10D }, .R11D);
    try validate(RegisterMemory_32, RegisterIndex_32, "R15D, R8D", &.{ 0x45, 0x89, 0xC7 }, mov.rm32_r32, .{ .reg = .R15D }, .R8D);
}

test "MOV 32 bit registers reverse encoding" {
    try validate(RegisterIndex_32, RegisterMemory_32, "EAX, ECX", &.{ 0x8B, 0xC1 }, mov.r32_rm32, .EAX, .{ .reg = .ECX });
    try validate(RegisterIndex_32, RegisterMemory_32, "R8D, EAX", &.{ 0x44, 0x8B, 0xC0 }, mov.r32_rm32, .R8D, .{ .reg = .EAX });
    try validate(RegisterIndex_32, RegisterMemory_32, "EBX, R9D", &.{ 0x41, 0x8B, 0xD9 }, mov.r32_rm32, .EBX, .{ .reg = .R9D });
    try validate(RegisterIndex_32, RegisterMemory_32, "EDI, R13D", &.{ 0x41, 0x8B, 0xFD }, mov.r32_rm32, .EDI, .{ .reg = .R13D });
}

test "MOV 32 bit immediate to r/m32 encoding" {
    try validate(RegisterMemory_32, u32, "EAX, 0x1234_5678", &.{ 0xC7, 0xC0, 0x78, 0x56, 0x34, 0x12 }, mov.rm32_imm32, .{ .reg = .EAX }, 0x1234_5678);
    try validate(RegisterMemory_32, u32, "R9D, 0x1234_5678", &.{ 0x41, 0xC7, 0xC1, 0x78, 0x56, 0x34, 0x12 }, mov.rm32_imm32, .{ .reg = .R9D }, 0x1234_5678);
    try validate(RegisterMemory_32, u32, "EDI, 0x89AB_CDEF", &.{ 0xC7, 0xC7, 0xEF, 0xCD, 0xAB, 0x89 }, mov.rm32_imm32, .{ .reg = .EDI }, 0x89AB_CDEF);
}

test "MOV 32bit immediate to register" {
    try validate(RegisterIndex_32, u32, "EAX, 0x12_34_56_78", &.{ 0xB8, 0x78, 0x56, 0x34, 0x12 }, mov.r32_imm32, .EAX, 0x12345678);
    try validate(RegisterIndex_32, u32, "R8D, 0x12_34_12_34", &.{ 0x41, 0xB8, 0x34, 0x12, 0x34, 0x12 }, mov.r32_imm32, .R8D, 0x12341234);
    try validate(RegisterIndex_32, u32, "R15D, 0xEF_EF_EF_EF", &.{ 0x41, 0xBF, 0xEF, 0xEF, 0xEF, 0xEF }, mov.r32_imm32, .R15D, 0xEFEFEFEF);
    try validate(RegisterIndex_32, u32, "R12D, 0x00_00_00_00", &.{ 0x41, 0xBC, 0x00, 0x00, 0x00, 0x00 }, mov.r32_imm32, .R12D, 0x00000000);
    try validate(RegisterIndex_32, u32, "R13D, 0x0F_0F_0F_0F", &.{ 0x41, 0xBD, 0x0F, 0x0F, 0x0F, 0x0F }, mov.r32_imm32, .R13D, 0x0F0F0F0F);
    try validate(RegisterIndex_32, u32, "R9D, 0x00_00_00_FF", &.{ 0x41, 0xB9, 0xFF, 0x00, 0x00, 0x00 }, mov.r32_imm32, .R9D, 0x000000FF);
}

test "MOV 32 bit RIP-relative memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[RIP + 0x1234], ECX",
        &.{ 0x89, 0x0D, 0x34, 0x12, 0x00, 0x00 },
        mov.rm32_r32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .ECX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R9D, [RIP - 16]",
        &.{ 0x44, 0x8B, 0x0D, 0xF0, 0xFF, 0xFF, 0xFF },
        mov.r32_rm32,
        .R9D,
        .{ .mem = .{ .ripRelative = -16 } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[RIP + 0x1234], 0x89AB_CDEF",
        &.{ 0xC7, 0x05, 0x34, 0x12, 0x00, 0x00, 0xEF, 0xCD, 0xAB, 0x89 },
        mov.rm32_imm32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        0x89AB_CDEF,
    );
}

test "MOV 32 bit base-index64 memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[R8], EAX",
        &.{ 0x41, 0x89, 0x00 },
        mov.rm32_r32,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .EAX,
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[R9 + 4], EAX",
        &.{ 0x41, 0x89, 0x41, 0x04 },
        mov.rm32_r32,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .EAX,
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[RAX + R10*2 - 4], 0x11223344",
        &.{ 0x42, 0xC7, 0x44, 0x50, 0xFC, 0x44, 0x33, 0x22, 0x11 },
        mov.rm32_imm32,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{
                        .reg = .R10,
                        .scale = .x2,
                    },
                    .disp = -4,
                },
            },
        },
        0x1122_3344,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [R8]",
        &.{ 0x45, 0x8B, 0x18 },
        mov.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [R9 + 4]",
        &.{ 0x45, 0x8B, 0x59, 0x04 },
        mov.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[RAX + R10*8 + 0x10], R11D",
        &.{ 0x46, 0x89, 0x5C, 0xD0, 0x10 },
        mov.rm32_r32,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = .RAX,
                    .index = .{
                        .reg = .R10,
                        .scale = .x8,
                    },
                    .disp = 0x10,
                },
            },
        },
        .R11D,
    );
}

test "MOV 32 bit base-index32 memory" {
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[EBX + ECX*2], EAX",
        &.{ 0x67, 0x89, 0x04, 0x4B },
        mov.rm32_r32,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = .EBX,
                    .index = .{
                        .reg = .ECX,
                        .scale = .x2,
                    },
                },
            },
        },
        .EAX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [EBX + ECX*2]",
        &.{ 0x67, 0x44, 0x8B, 0x1C, 0x4B },
        mov.r32_rm32,
        .R11D,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = .EBX,
                    .index = .{
                        .reg = .ECX,
                        .scale = .x2,
                    },
                },
            },
        },
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[R8D], EAX",
        &.{ 0x67, 0x41, 0x89, 0x00 },
        mov.rm32_r32,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
        .EAX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [R8D]",
        &.{ 0x67, 0x45, 0x8B, 0x18 },
        mov.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[EBP], 0x11223344",
        &.{ 0x67, 0xC7, 0x45, 0x00, 0x44, 0x33, 0x22, 0x11 },
        mov.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x1122_3344,
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[ECX*4 + 0x1234], EAX",
        &.{ 0x67, 0x89, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        mov.rm32_r32,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = null,
                    .index = .{
                        .reg = .ECX,
                        .scale = .x4,
                    },
                    .disp = 0x1234,
                },
            },
        },
        .EAX,
    );
    try validate(
        RegisterMemory_32,
        RegisterIndex_32,
        "[addr32:0x1234], EAX",
        &.{ 0x67, 0x89, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        mov.rm32_r32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        .EAX,
    );
    try validate(
        RegisterIndex_32,
        RegisterMemory_32,
        "R11D, [addr32:0x1234]",
        &.{ 0x67, 0x44, 0x8B, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        mov.r32_rm32,
        .R11D,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
    );
    try validate(
        RegisterMemory_32,
        u32,
        "[addr32:0x1234], 0x11223344",
        &.{ 0x67, 0xC7, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        mov.rm32_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = null, .index = null, .disp = 0x1234 } } },
        0x1122_3344,
    );
}

test "MOV 32 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, mov.rm32_r32(&writer, .{ .reg = .EAX }, .ECX));
    try std.testing.expectError(EncodingError.WriterError, mov.r32_rm32(&writer, .EAX, .{ .reg = .ECX }));
    try std.testing.expectError(EncodingError.WriterError, mov.rm32_imm32(&writer, .{ .reg = .EAX }, 0x1234_5678));
    try std.testing.expectError(EncodingError.WriterError, mov.r32_imm32(&writer, .EAX, 0x1234_5678));
}
