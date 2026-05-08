const std = @import("std");

const Engine = @import("../engine.zig");

test "asm engine mov register immediate" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    try engine.mov(.rax, .{ .imm = 0x21 });
    try std.testing.expectEqualSlices(u8, &.{ 0x48, 0xC7, 0xC0, 0x21, 0x00, 0x00, 0x00 }, engine.bytes());
}

test "asm engine mov sized memory immediate" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    try engine.mov(
        .{ .mem = .{ .size = .qword, .reg = .rbp, .disp = -8 } },
        .{ .imm = 0 },
    );
    try std.testing.expectEqualSlices(u8, &.{ 0x48, 0xC7, 0x45, 0xF8, 0x00, 0x00, 0x00, 0x00 }, engine.bytes());
}
