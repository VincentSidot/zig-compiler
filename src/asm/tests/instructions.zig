const std = @import("std");

const Engine = @import("../engine.zig");
const Arg = Engine.Arg;

test "asm engine arithmetic helpers" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    try engine.add(.rax, Arg.immediate(1));
    try engine.cmp(.rax, Arg.immediate(1));
    try engine.sub(.rsp, Arg.immediate(8));
    try engine.xor(.eax, .eax);
    try engine.@"and"(.rax, .rcx);
    try engine.@"or"(.eax, Arg.immediate(0x7f));
    try engine.@"test"(.al, Arg.immediate(1));
    try engine.@"test"(.al, Arg.raw8(0xff));
    try engine.inc(.rax);
    try engine.dec(.{ .mem = .{ .size = .byte, .reg = .rax } });

    try std.testing.expectEqualSlices(u8, &.{
        0x48, 0x81, 0xC0, 0x01, 0x00, 0x00, 0x00,
        0x48, 0x81, 0xF8, 0x01, 0x00, 0x00, 0x00,
        0x48, 0x81, 0xEC, 0x08, 0x00, 0x00, 0x00,
        0x33, 0xC0, 0x48, 0x23, 0xC1, 0x81, 0xC8,
        0x7F, 0x00, 0x00, 0x00, 0xF6, 0xC0, 0x01,
        0xF6, 0xC0, 0xFF, 0x48, 0xFF, 0xC0, 0xFE,
        0x08,
    }, engine.bytes());
}

test "asm engine stack and control helpers" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const target = try engine.label();
    try engine.push(.rbp);
    try engine.pop(.rbp);
    try engine.call(.{ .label = target });
    try engine.jcc(.e, .{ .label = target });
    try engine.ret();
    try engine.syscall();
    try engine.bind(target);

    try std.testing.expectEqualSlices(u8, &.{
        0x55,
        0x5D,
        0xE8,
        0x00,
        0x00,
        0x00,
        0x00,
        0x0F,
        0x84,
        0x00,
        0x00,
        0x00,
        0x00,
        0xC3,
        0x0F,
        0x05,
    }, engine.bytes());
}

test "asm engine lea helper" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    try engine.lea(.rax, .{ .mem = .{ .size = .qword, .reg = .rbp, .disp = -8 } });
    try engine.lea(.eax, .{ .mem = .{ .size = .dword, .reg = .ebx, .disp = 4 } });

    try std.testing.expectEqualSlices(u8, &.{
        0x48, 0x8D, 0x45, 0xF8,
        0x67, 0x8D, 0x43, 0x04,
    }, engine.bytes());
}
