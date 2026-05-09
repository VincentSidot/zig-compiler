const std = @import("std");

const Engine = @import("../engine.zig");
const Arg = Engine.Arg;

test "asm engine mov register immediate" {
    var engine = Engine.init(std.testing.allocator);

    engine.mov(.rax, Arg.immediate(0x21));
    const bytes = try engine.finalize();
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &.{ 0x48, 0xC7, 0xC0, 0x21, 0x00, 0x00, 0x00 }, bytes);
}

test "asm engine mov sized memory immediate" {
    var engine = Engine.init(std.testing.allocator);

    engine.mov(
        .{ .mem = .{ .size = .qword, .reg = .rbp, .disp = -8 } },
        Arg.immediate(0),
    );
    const bytes = try engine.finalize();
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualSlices(u8, &.{ 0x48, 0xC7, 0x45, 0xF8, 0x00, 0x00, 0x00, 0x00 }, bytes);
}
