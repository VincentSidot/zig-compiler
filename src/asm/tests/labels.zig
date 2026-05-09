const std = @import("std");

const Engine = @import("../engine.zig");

test "asm engine label branch relaxes to rel8" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const target = try engine.label();
    engine.jmp(.{ .label = target });
    try engine.bind(target);

    try engine.finalize();
    const bytes = engine.bytes();
    try std.testing.expectEqualSlices(u8, &.{ 0xEB, 0x00 }, bytes);
}

test "asm engine branch target forms" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    engine.jmp(.{ .rel = 0x1234 });
    engine.jmp(.{ .reg = .rax });
    engine.jmp(.{ .mem = .{ .reg = .rax } });
    engine.call(.{ .reg = .r9 });
    engine.jcc(.e, .{ .rel = -4 });

    try engine.finalize();
    const bytes = engine.bytes();
    try std.testing.expectEqualSlices(u8, &.{
        0xE9, 0x34, 0x12, 0x00, 0x00,
        0xFF, 0xE0, 0xFF, 0x20, 0x41,
        0xFF, 0xD1, 0x0F, 0x84, 0xFC,
        0xFF, 0xFF, 0xFF,
    }, bytes);
}
