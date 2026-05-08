const std = @import("std");

const Engine = @import("../engine.zig");

test "asm engine label branch emits rel32 placeholder" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const target = try engine.label();
    try engine.jmp(.{ .label = target });
    try engine.bind(target);

    try std.testing.expectEqualSlices(u8, &.{ 0xE9, 0x00, 0x00, 0x00, 0x00 }, engine.bytes());
}

test "asm engine branch target forms" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    try engine.jmp(.{ .rel = 0x1234 });
    try engine.jmp(.{ .reg = .rax });
    try engine.jmp(.{ .mem = .{ .size = .qword, .reg = .rax } });
    try engine.call(.{ .reg = .r9 });
    try engine.jcc(.e, .{ .rel = -4 });

    try std.testing.expectEqualSlices(u8, &.{
        0xE9, 0x34, 0x12, 0x00, 0x00,
        0xFF, 0xE0, 0xFF, 0x20, 0x41,
        0xFF, 0xD1, 0x0F, 0x84, 0xFC,
        0xFF, 0xFF, 0xFF,
    }, engine.bytes());
}

test "asm engine rejects invalid branch target forms" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    try std.testing.expectError(error.InvalidOperand, engine.jcc(.e, .{ .reg = .rax }));
    try std.testing.expectError(error.InvalidOperand, engine.jcc(.e, .{ .mem = .{ .size = .qword, .reg = .rax } }));
    try std.testing.expectError(error.InvalidOperand, engine.jmp(.{ .reg = .eax }));
    try std.testing.expectError(error.InvalidOperand, engine.call(.{ .mem = .{ .size = .byte, .reg = .rax } }));
}
