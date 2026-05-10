const std = @import("std");

const Engine = @import("../engine.zig");
const Arg = Engine.Arg;

test "asm engine arithmetic helpers" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    engine.add(.rax, Arg.immediate(1));
    engine.cmp(.rax, Arg.immediate(1));
    engine.sub(.rsp, Arg.immediate(8));
    engine.xor(.eax, .eax);
    engine.@"and"(.rax, .rcx);
    engine.@"or"(.eax, Arg.immediate(0x7f));
    engine.@"test"(.al, Arg.immediate(1));
    engine.@"test"(.al, Arg.raw8(0xff));
    engine.inc(.rax);
    engine.dec(.{ .mem = .{ .size = .byte, .reg = .rax } });

    try engine.finalize();
    const bytes = engine.bytes();
    try std.testing.expectEqualSlices(u8, &.{
        0x48, 0x81, 0xC0, 0x01, 0x00, 0x00, 0x00,
        0x48, 0x81, 0xF8, 0x01, 0x00, 0x00, 0x00,
        0x48, 0x81, 0xEC, 0x08, 0x00, 0x00, 0x00,
        0x33, 0xC0, 0x48, 0x23, 0xC1, 0x81, 0xC8,
        0x7F, 0x00, 0x00, 0x00, 0xF6, 0xC0, 0x01,
        0xF6, 0xC0, 0xFF, 0x48, 0xFF, 0xC0, 0xFE,
        0x08,
    }, bytes);
}

test "asm engine stack and control helpers" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const target = try engine.label();
    engine.push(.rbp);
    engine.pop(.rbp);
    engine.call(.{ .label = target });
    engine.jcc(.e, .{ .label = target });
    engine.ret();
    engine.syscall();
    try engine.bind(target);

    try engine.finalize();
    const bytes = engine.bytes();
    try std.testing.expectEqualSlices(u8, &.{
        0x55,
        0x5D,
        0xE8,
        0x05,
        0x00,
        0x00,
        0x00,
        0x74,
        0x03,
        0xC3,
        0x0F,
        0x05,
    }, bytes);
}

test "asm engine lea helper" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    engine.lea(.rax, .{ .mem = .{ .size = .qword, .reg = .rbp, .disp = -8 } });
    engine.lea(.eax, .{ .mem = .{ .size = .dword, .reg = .ebx, .disp = 4 } });

    try engine.finalize();
    const bytes = engine.bytes();
    try std.testing.expectEqualSlices(u8, &.{
        0x48, 0x8D, 0x45, 0xF8,
        0x67, 0x8D, 0x43, 0x04,
    }, bytes);
}

test "asm engine patches symbol-backed mov imm64" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const sym = try engine.symbol();
    engine.mov(.rdi, Arg.sym64(sym));

    try engine.finalize();
    try engine.patchInPlace(sym, 0x1122_3344_5566_7788);

    try std.testing.expectEqualSlices(u8, &.{
        0x48, 0xBF, 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11,
    }, engine.bytes());
}

test "asm engine patches taken bytecode" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const sym = try engine.symbol();
    engine.mov(.rdi, Arg.sym64(sym));

    try engine.finalize();
    const bytes = try engine.takeBytes();
    defer std.testing.allocator.free(bytes);

    try engine.patch(bytes, sym, 0x8877_6655_4433_2211);

    try std.testing.expectEqualSlices(u8, &.{
        0x48, 0xBF, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88,
    }, bytes);
}
