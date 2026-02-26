const std = @import("std");
const common = @import("common.zig");

const mov = common.mov;
const validate = common.validate;
const EncodingError = common.EncodingError;
const RegisterIndex_32 = common.RegisterIndex_32;
const RegisterMemory_32 = common.RegisterMemory_32;

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
}

test "MOV 32 bit immediate to r/m32 encoding" {
    try validate(RegisterMemory_32, u32, "EAX, 0x1234_5678", &.{ 0xC7, 0xC0, 0x78, 0x56, 0x34, 0x12 }, mov.rm32_imm32, .{ .reg = .EAX }, 0x1234_5678);
    try validate(RegisterMemory_32, u32, "R9D, 0x1234_5678", &.{ 0x41, 0xC7, 0xC1, 0x78, 0x56, 0x34, 0x12 }, mov.rm32_imm32, .{ .reg = .R9D }, 0x1234_5678);
}

test "MOV 32bit immediate to register" {
    try validate(RegisterIndex_32, u32, "R8D, 0x12_34_12_34", &.{ 0x41, 0xB8, 0x34, 0x12, 0x34, 0x12 }, mov.r32_imm32, .R8D, 0x12341234);
    try validate(RegisterIndex_32, u32, "R15D, 0xEF_EF_EF_EF", &.{ 0x41, 0xBF, 0xEF, 0xEF, 0xEF, 0xEF }, mov.r32_imm32, .R15D, 0xEFEFEFEF);
    try validate(RegisterIndex_32, u32, "R12D, 0x00_00_00_00", &.{ 0x41, 0xBC, 0x00, 0x00, 0x00, 0x00 }, mov.r32_imm32, .R12D, 0x00000000);
    try validate(RegisterIndex_32, u32, "R13D, 0x0F_0F_0F_0F", &.{ 0x41, 0xBD, 0x0F, 0x0F, 0x0F, 0x0F }, mov.r32_imm32, .R13D, 0x0F0F0F0F);
    try validate(RegisterIndex_32, u32, "R9D, 0x00_00_00_FF", &.{ 0x41, 0xB9, 0xFF, 0x00, 0x00, 0x00 }, mov.r32_imm32, .R9D, 0x000000FF);
}

test "MOV 32 bit writer errors" {
    var buffer: [0]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);
    try std.testing.expectError(EncodingError.WriterError, mov.rm32_r32(&writer, .{ .reg = .EAX }, .ECX));
    try std.testing.expectError(EncodingError.WriterError, mov.r32_rm32(&writer, .EAX, .{ .reg = .ECX }));
    try std.testing.expectError(EncodingError.WriterError, mov.rm32_imm32(&writer, .{ .reg = .EAX }, 0x1234_5678));
    try std.testing.expectError(EncodingError.WriterError, mov.r32_imm32(&writer, .EAX, 0x1234_5678));
}
