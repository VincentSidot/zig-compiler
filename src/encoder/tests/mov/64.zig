const std = @import("std");
const common = @import("common.zig");

const mov = common.mov;
const validate_impl = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_64 = common.RegisterIndex_64;
const RegisterMemory_64 = common.RegisterMemory_64;

pub var validate_calls = std.atomic.Value(usize).init(0);

fn validate(
    comptime Dest: type,
    comptime Src: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn (writer: *std.io.Writer, dest: Dest, source: Src) EncodingError!usize,
    dest: Dest,
    source: Src,
) !void {
    _ = validate_calls.fetchAdd(1, .monotonic);
    try validate_impl(Dest, Src, name, expected, tested, dest, source);
}

test "MOV 64 bit registers" {
    try validate(RegisterMemory_64, RegisterIndex_64, "RAX, RCX", &.{ 0x48, 0x89, 0xC8 }, mov.rm64_r64, .{ .reg = .RAX }, .RCX);
    try validate(RegisterMemory_64, RegisterIndex_64, "RBX, RDX", &.{ 0x48, 0x89, 0xD3 }, mov.rm64_r64, .{ .reg = .RBX }, .RDX);
    try validate(RegisterMemory_64, RegisterIndex_64, "RSI, RDI", &.{ 0x48, 0x89, 0xFE }, mov.rm64_r64, .{ .reg = .RSI }, .RDI);
    try validate(RegisterMemory_64, RegisterIndex_64, "RDI, RAX", &.{ 0x48, 0x89, 0xC7 }, mov.rm64_r64, .{ .reg = .RDI }, .RAX);
}

test "MOV 64 bit registers extended" {
    try validate(RegisterMemory_64, RegisterIndex_64, "R8, RAX", &.{ 0x49, 0x89, 0xC0 }, mov.rm64_r64, .{ .reg = .R8 }, .RAX);
    try validate(RegisterMemory_64, RegisterIndex_64, "RAX, R8", &.{ 0x4C, 0x89, 0xC0 }, mov.rm64_r64, .{ .reg = .RAX }, .R8);
    try validate(RegisterMemory_64, RegisterIndex_64, "R8, R9", &.{ 0x4D, 0x89, 0xC8 }, mov.rm64_r64, .{ .reg = .R8 }, .R9);
    try validate(RegisterMemory_64, RegisterIndex_64, "R10, R11", &.{ 0x4D, 0x89, 0xDA }, mov.rm64_r64, .{ .reg = .R10 }, .R11);
    try validate(RegisterMemory_64, RegisterIndex_64, "R15, R8", &.{ 0x4D, 0x89, 0xC7 }, mov.rm64_r64, .{ .reg = .R15 }, .R8);
    try validate(RegisterMemory_64, RegisterIndex_64, "R8, RDI", &.{ 0x49, 0x89, 0xF8 }, mov.rm64_r64, .{ .reg = .R8 }, .RDI);
    try validate(RegisterMemory_64, RegisterIndex_64, "RDI, R8", &.{ 0x4C, 0x89, 0xC7 }, mov.rm64_r64, .{ .reg = .RDI }, .R8);
    try validate(RegisterMemory_64, RegisterIndex_64, "R12, R13", &.{ 0x4D, 0x89, 0xEC }, mov.rm64_r64, .{ .reg = .R12 }, .R13);
}

test "MOV 64 bit registers reverse encoding" {
    try validate(RegisterIndex_64, RegisterMemory_64, "RAX, RCX", &.{ 0x48, 0x8B, 0xC1 }, mov.r64_rm64, .RAX, .{ .reg = .RCX });
    try validate(RegisterIndex_64, RegisterMemory_64, "R8, RAX", &.{ 0x4C, 0x8B, 0xC0 }, mov.r64_rm64, .R8, .{ .reg = .RAX });
    try validate(RegisterIndex_64, RegisterMemory_64, "RBX, R9", &.{ 0x49, 0x8B, 0xD9 }, mov.r64_rm64, .RBX, .{ .reg = .R9 });
    try validate(RegisterIndex_64, RegisterMemory_64, "RDI, R13", &.{ 0x49, 0x8B, 0xFD }, mov.r64_rm64, .RDI, .{ .reg = .R13 });
}

test "MOV 64 bit immediate to r/m64 encoding" {
    try validate(RegisterMemory_64, u32, "RAX, 0x1234_5678", &.{ 0x48, 0xC7, 0xC0, 0x78, 0x56, 0x34, 0x12 }, mov.rm64_imm32, .{ .reg = .RAX }, 0x1234_5678);
    try validate(RegisterMemory_64, u32, "R9, 0x1234_5678", &.{ 0x49, 0xC7, 0xC1, 0x78, 0x56, 0x34, 0x12 }, mov.rm64_imm32, .{ .reg = .R9 }, 0x1234_5678);
    try validate(RegisterMemory_64, u32, "RDI, 0x89AB_CDEF", &.{ 0x48, 0xC7, 0xC7, 0xEF, 0xCD, 0xAB, 0x89 }, mov.rm64_imm32, .{ .reg = .RDI }, 0x89AB_CDEF);
}

test "MOV 64 bit immediate64 direct encoding" {
    try validate(RegisterIndex_64, u64, "RAX, 0x1122_3344_5566_7788", &.{ 0x48, 0xB8, 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11 }, mov.r64_imm64, .RAX, 0x1122_3344_5566_7788);
    try validate(RegisterIndex_64, u64, "R9, 0x0102_0304_0506_0708", &.{ 0x49, 0xB9, 0x08, 0x07, 0x06, 0x05, 0x04, 0x03, 0x02, 0x01 }, mov.r64_imm64, .R9, 0x0102_0304_0506_0708);
    try validate(RegisterIndex_64, u64, "RBX, 0x0011_2233_4455_6677", &.{ 0x48, 0xBB, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11, 0x00 }, mov.r64_imm64, .RBX, 0x0011_2233_4455_6677);
    try validate(RegisterIndex_64, u64, "R15, 0x8899_AABB_CCDD_EEFF", &.{ 0x49, 0xBF, 0xFF, 0xEE, 0xDD, 0xCC, 0xBB, 0xAA, 0x99, 0x88 }, mov.r64_imm64, .R15, 0x8899_AABB_CCDD_EEFF);
}

test "MOV 64 bit immediate to register" {
    try validate(RegisterIndex_64, u64, "RDI, 0xFF", &.{ 0x48, 0xC7, 0xC7, 0xFF, 0x00, 0x00, 0x00 }, mov.r64_imm64_auto, .RDI, 0x0000_0000_0000_00FF);
    try validate(RegisterIndex_64, u64, "RAX, 0x0C", &.{ 0x48, 0xC7, 0xC0, 0x0C, 0x00, 0x00, 0x00 }, mov.r64_imm64_auto, .RAX, 0x0000_0000_0000_000C);
    try validate(RegisterIndex_64, u64, "RDX, -12", &.{ 0x48, 0xC7, 0xC2, 0xF4, 0xFF, 0xFF, 0xFF }, mov.r64_imm64_auto, .RDX, 0xFFFF_FFFF_FFFF_FFF4);
    try validate(RegisterIndex_64, u64, "RSI, 0xFFFF_FFFF", &.{ 0x48, 0xBE, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00 }, mov.r64_imm64_auto, .RSI, 0x0000_0000_FFFF_FFFF);
    try validate(RegisterIndex_64, u64, "RAX, 0xEFFF_1234_1234_1234", &.{ 0x48, 0xB8, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12, 0xFF, 0xEF }, mov.r64_imm64_auto, .RAX, 0xEFFF_1234_5678_9ABC);
}

test "MOV 64 bit immediate to register extended" {
    try validate(RegisterIndex_64, u64, "R8, 0x1234_1234_1234_1234", &.{ 0x49, 0xB8, 0x34, 0x12, 0x34, 0x12, 0x34, 0x12, 0x34, 0x12 }, mov.r64_imm64_auto, .R8, 0x1234_1234_1234_1234);
    try validate(RegisterIndex_64, u64, "R15, 0xEFFF_1234_1234_1234", &.{ 0x49, 0xBF, 0x34, 0x12, 0x34, 0x12, 0x34, 0x12, 0xFF, 0xEF }, mov.r64_imm64_auto, .R15, 0xEFFF_1234_1234_1234);
    try validate(RegisterIndex_64, u64, "R12, 0x0", &.{ 0x49, 0xC7, 0xC4, 0x00, 0x00, 0x00, 0x00 }, mov.r64_imm64_auto, .R12, 0x0000_0000_0000_0000);
    try validate(RegisterIndex_64, u64, "R13, 0xF0F0_F0F0_F0F0_F000", &.{ 0x49, 0xBD, 0xF0, 0xDE, 0xBC, 0x9A, 0x78, 0x56, 0x34, 0x12 }, mov.r64_imm64_auto, .R13, 0x1234_5678_9ABC_DEF0);
}

test "MOV 64 bit immediate auto boundary values" {
    try validate(RegisterIndex_64, u64, "RAX, 0x0000_0000_7FFF_FFFF", &.{ 0x48, 0xC7, 0xC0, 0xFF, 0xFF, 0xFF, 0x7F }, mov.r64_imm64_auto, .RAX, 0x0000_0000_7FFF_FFFF);
    try validate(RegisterIndex_64, u64, "RAX, 0x0000_0000_8000_0000", &.{ 0x48, 0xB8, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00 }, mov.r64_imm64_auto, .RAX, 0x0000_0000_8000_0000);
    try validate(RegisterIndex_64, u64, "RAX, 0xFFFF_FFFF_8000_0000", &.{ 0x48, 0xC7, 0xC0, 0x00, 0x00, 0x00, 0x80 }, mov.r64_imm64_auto, .RAX, 0xFFFF_FFFF_8000_0000);
}

test "MOV 64 bit RIP-relative memory" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RIP + 0x1234], RAX",
        &.{ 0x48, 0x89, 0x05, 0x34, 0x12, 0x00, 0x00 },
        mov.rm64_r64,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "R9, [RIP - 24]",
        &.{ 0x4C, 0x8B, 0x0D, 0xE8, 0xFF, 0xFF, 0xFF },
        mov.r64_rm64,
        .R9,
        .{ .mem = .{ .ripRelative = -24 } },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[RIP + 0x1234], 0x89AB_CDEF",
        &.{ 0x48, 0xC7, 0x05, 0x34, 0x12, 0x00, 0x00, 0xEF, 0xCD, 0xAB, 0x89 },
        mov.rm64_imm32,
        .{ .mem = .{ .ripRelative = 0x1234 } },
        0x89AB_CDEF,
    );
}

test "MOV 64 bit absolute disp32 memory (no base/index)" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[0x1234], RAX",
        &.{ 0x48, 0x89, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        mov.rm64_r64,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = null,
                    .index = null,
                    .disp = 0x1234,
                },
            },
        },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "R11, [0x1234]",
        &.{ 0x4C, 0x8B, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        mov.r64_rm64,
        .R11,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = null,
                    .index = null,
                    .disp = 0x1234,
                },
            },
        },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[0x1234], 0x11223344",
        &.{ 0x48, 0xC7, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        mov.rm64_imm32,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = null,
                    .index = null,
                    .disp = 0x1234,
                },
            },
        },
        0x1122_3344,
    );
}

test "MOV 64 bit base-index memory (draft encoder)" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[R8], RAX",
        &.{ 0x49, 0x89, 0x00 },
        mov.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
        .RAX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[R9 + 4], RAX",
        &.{ 0x49, 0x89, 0x41, 0x04 },
        mov.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
        .RAX,
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[RAX + R10*2 - 4], 0x12345678",
        &.{ 0x4A, 0xC7, 0x44, 0x50, 0xFC, 0x78, 0x56, 0x34, 0x12 },
        mov.rm64_imm32,
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
        0x12345678,
    );

    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "RAX, [R8]",
        &.{ 0x49, 0x8B, 0x00 },
        mov.r64_rm64,
        .RAX,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R8 } } },
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "R11, [R9 + 4]",
        &.{ 0x4D, 0x8B, 0x59, 0x04 },
        mov.r64_rm64,
        .R11,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R9, .disp = 4 } } },
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RAX + R10*8 + 0x10], R11",
        &.{ 0x4E, 0x89, 0x5C, 0xD0, 0x10 },
        mov.rm64_r64,
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
        .R11,
    );
}

test "MOV 64 bit base-index memory edge cases" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[R12], RAX",
        &.{ 0x49, 0x89, 0x04, 0x24 },
        mov.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R12 } } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "RAX, [R12]",
        &.{ 0x49, 0x8B, 0x04, 0x24 },
        mov.r64_rm64,
        .RAX,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R12 } } },
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[R13], RAX",
        &.{ 0x49, 0x89, 0x45, 0x00 },
        mov.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R13 } } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "RAX, [R13]",
        &.{ 0x49, 0x8B, 0x45, 0x00 },
        mov.r64_rm64,
        .RAX,
        .{ .mem = .{ .baseIndex64 = .{ .base = .R13 } } },
    );

    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RAX - 128], RCX",
        &.{ 0x48, 0x89, 0x48, 0x80 },
        mov.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = -128 } } },
        .RCX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RAX - 129], RCX",
        &.{ 0x48, 0x89, 0x88, 0x7F, 0xFF, 0xFF, 0xFF },
        mov.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = -129 } } },
        .RCX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RAX + 127], RCX",
        &.{ 0x48, 0x89, 0x48, 0x7F },
        mov.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = 127 } } },
        .RCX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RAX + 128], RCX",
        &.{ 0x48, 0x89, 0x88, 0x80, 0x00, 0x00, 0x00 },
        mov.rm64_r64,
        .{ .mem = .{ .baseIndex64 = .{ .base = .RAX, .disp = 128 } } },
        .RCX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[RCX*4 + 0x1234], RAX",
        &.{ 0x48, 0x89, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        mov.rm64_r64,
        .{
            .mem = .{
                .baseIndex64 = .{
                    .base = null,
                    .index = .{
                        .reg = .RCX,
                        .scale = .x4,
                    },
                    .disp = 0x1234,
                },
            },
        },
        .RAX,
    );
}

test "MOV 64 bit base-index32 memory" {
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[EBX + ECX*2], RAX",
        &.{ 0x67, 0x48, 0x89, 0x04, 0x4B },
        mov.rm64_r64,
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
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "RAX, [EBX + ECX*2]",
        &.{ 0x67, 0x48, 0x8B, 0x04, 0x4B },
        mov.r64_rm64,
        .RAX,
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
        RegisterMemory_64,
        RegisterIndex_64,
        "[R8D], RAX",
        &.{ 0x67, 0x49, 0x89, 0x00 },
        mov.rm64_r64,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "RAX, [R8D]",
        &.{ 0x67, 0x49, 0x8B, 0x00 },
        mov.r64_rm64,
        .RAX,
        .{ .mem = .{ .baseIndex32 = .{ .base = .R8D } } },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[EBP], 0x11223344",
        &.{ 0x67, 0x48, 0xC7, 0x45, 0x00, 0x44, 0x33, 0x22, 0x11 },
        mov.rm64_imm32,
        .{ .mem = .{ .baseIndex32 = .{ .base = .EBP } } },
        0x11223344,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[ECX*4 + 0x1234], RAX",
        &.{ 0x67, 0x48, 0x89, 0x04, 0x8D, 0x34, 0x12, 0x00, 0x00 },
        mov.rm64_r64,
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
        .RAX,
    );
    try validate(
        RegisterMemory_64,
        RegisterIndex_64,
        "[addr32:0x1234], RAX",
        &.{ 0x67, 0x48, 0x89, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00 },
        mov.rm64_r64,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = null,
                    .index = null,
                    .disp = 0x1234,
                },
            },
        },
        .RAX,
    );
    try validate(
        RegisterIndex_64,
        RegisterMemory_64,
        "R11, [addr32:0x1234]",
        &.{ 0x67, 0x4C, 0x8B, 0x1C, 0x25, 0x34, 0x12, 0x00, 0x00 },
        mov.r64_rm64,
        .R11,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = null,
                    .index = null,
                    .disp = 0x1234,
                },
            },
        },
    );
    try validate(
        RegisterMemory_64,
        u32,
        "[addr32:0x1234], 0x11223344",
        &.{ 0x67, 0x48, 0xC7, 0x04, 0x25, 0x34, 0x12, 0x00, 0x00, 0x44, 0x33, 0x22, 0x11 },
        mov.rm64_imm32,
        .{
            .mem = .{
                .baseIndex32 = .{
                    .base = null,
                    .index = null,
                    .disp = 0x1234,
                },
            },
        },
        0x1122_3344,
    );
}

test "MOV 64 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, mov.rm64_r64(&writer, .{ .reg = .RAX }, .RCX));
    try std.testing.expectError(EncodingError.WriterError, mov.r64_rm64(&writer, .RAX, .{ .reg = .RCX }));
    try std.testing.expectError(EncodingError.WriterError, mov.rm64_imm32(&writer, .{ .reg = .RAX }, 0x1234_5678));
    try std.testing.expectError(EncodingError.WriterError, mov.r64_imm64(&writer, .RAX, 0x1122_3344_5566_7788));
    try std.testing.expectError(EncodingError.WriterError, mov.r64_imm64_auto(&writer, .RAX, 0x0000_0000_0000_0001));
}
