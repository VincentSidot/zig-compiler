const std = @import("std");
const loader = @import("../loader.zig");
const encoder = @import("../encoder/lib.zig");

fn buildFibBytecode(allocator: std.mem.Allocator) ![]u8 {
    const op = encoder.opcode;

    var writer_alloc = std.Io.Writer.Allocating.init(allocator);
    errdefer writer_alloc.deinit();

    const writer = &writer_alloc.writer;
    var written: usize = 0;

    // rcx = n
    written += try op.mov.r64_r64(writer, .RCX, .RDI);
    // if (n <= 1) goto ret_n
    written += try op.cmp.r64_imm32(writer, .RCX, 1);
    const ret_n_jle_addr = written;
    written += try op.jcc.rel32(writer, .le, 0);

    // a = 0 (rax), b = 1 (rdx)
    written += try op.mov.r64_imm64_auto(writer, .RAX, 0);
    written += try op.mov.r64_imm64_auto(writer, .RDX, 1);

    const loop_addr = written;

    // tmp = b (r8)
    written += try op.mov.r64_r64(writer, .R8, .RDX);
    // tmp += a
    written += try op.add.rm64_r64(writer, .{ .reg = .R8 }, .RAX);
    // a = b
    written += try op.mov.r64_r64(writer, .RAX, .RDX);
    // b = tmp
    written += try op.mov.r64_r64(writer, .RDX, .R8);

    // n--
    written += try op.sub.r64_imm32(writer, .RCX, 1);
    // while (n > 1) loop
    written += try op.cmp.r64_imm32(writer, .RCX, 1);
    const loop_jg_addr = written;
    written += try op.jcc.rel32(writer, .g, 0);

    // return b
    written += try op.mov.r64_r64(writer, .RAX, .RDX);
    written += try op.ret(writer, .Default);

    const ret_n_addr = written;
    // return n
    written += try op.mov.r64_r64(writer, .RAX, .RCX);
    written += try op.ret(writer, .Default);

    const buffer = writer.buffer;
    try op.jcc.patch_rel32(buffer, ret_n_jle_addr, ret_n_addr);
    try op.jcc.patch_rel32(buffer, loop_jg_addr, loop_addr);

    return try writer_alloc.toOwnedSlice();
}

test "loader: load and execute minimal function from memory" {
    const Fn = fn () callconv(.c) void;
    // x86-64: ret
    const bytecode = [_]u8{0xC3};

    const loaded = try loader.load_from_memory(Fn, bytecode[0..]);
    defer loaded.deinit();

    const f = loaded.f();
    f();
}

test "loader: empty bytecode returns error" {
    const Fn = fn () callconv(.c) void;
    const empty = [_]u8{};

    try std.testing.expectError(error.EmptyData, loader.load_from_memory(Fn, empty[0..]));
}

test "loader: encoded fibonacci returns expected values" {
    const allocator = std.testing.allocator;
    const Fn = fn (u64) callconv(.c) u64;

    const bytecode = try buildFibBytecode(allocator);
    defer allocator.free(bytecode);

    const loaded = try loader.load_from_memory(Fn, bytecode);
    defer loaded.deinit();

    const f = loaded.f();

    const cases = [_]struct { n: u64, expect: u64 }{
        .{ .n = 0, .expect = 0 },
        .{ .n = 1, .expect = 1 },
        .{ .n = 2, .expect = 1 },
        .{ .n = 3, .expect = 2 },
        .{ .n = 5, .expect = 5 },
        .{ .n = 10, .expect = 55 },
    };

    for (cases) |case| {
        try std.testing.expectEqual(case.expect, f(case.n));
    }
}
