const std = @import("std");

const elf = @import("../lib.zig");
const Engine = elf.Engine;

test "elf engine lays out first segment directly after headers" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const text = try engine.segment(.{
        .kind = .text,
        .flags = .{ .read = true, .execute = true },
    });
    const data = try engine.segment(.{
        .kind = .data,
        .flags = .{ .read = true, .write = true },
    });

    _ = try engine.append(text, "code");
    _ = try engine.append(data, "data");
    try engine.setEntry(text, 0);

    const bytes = try engine.finalize();
    defer std.testing.allocator.free(bytes);

    const Elf64_Ehdr = std.elf.Elf64_Ehdr;
    const Elf64_Phdr = std.elf.Elf64_Phdr;
    const header_size = @sizeOf(Elf64_Ehdr) + 2 * @sizeOf(Elf64_Phdr);
    const ehdr = std.mem.bytesAsValue(Elf64_Ehdr, bytes[0..@sizeOf(Elf64_Ehdr)]);
    const phdr0 = std.mem.bytesAsValue(
        Elf64_Phdr,
        bytes[@sizeOf(Elf64_Ehdr) .. @sizeOf(Elf64_Ehdr) + @sizeOf(Elf64_Phdr)],
    );
    const phdr1_start = @sizeOf(Elf64_Ehdr) + @sizeOf(Elf64_Phdr);
    const phdr1 = std.mem.bytesAsValue(
        Elf64_Phdr,
        bytes[phdr1_start .. phdr1_start + @sizeOf(Elf64_Phdr)],
    );

    try std.testing.expectEqual(@as(u16, 2), ehdr.e_phnum);
    try std.testing.expectEqual(@as(u64, 0), phdr0.p_offset);
    try std.testing.expectEqual(@as(u64, header_size), phdr0.p_filesz - 4);
    try std.testing.expectEqual(@as(u64, header_size + 4), phdr1.p_offset);
    try std.testing.expectEqual(phdr1.p_offset % phdr1.p_align, phdr1.p_vaddr % phdr1.p_align);
}

test "elf engine patches rel32 from immediate field" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const text = try engine.segment(.{
        .kind = .text,
        .flags = .{ .read = true, .execute = true },
    });
    const data = try engine.segment(.{
        .kind = .data,
        .flags = .{ .read = true, .write = true },
    });

    _ = try engine.append(text, &.{ 0x90, 0, 0, 0, 0 });
    _ = try engine.append(data, "B");
    try engine.setEntry(text, 0);
    try engine.patchRel32(text, 1, data, 0);

    const bytes = try engine.finalize();
    defer std.testing.allocator.free(bytes);

    const Elf64_Ehdr = std.elf.Elf64_Ehdr;
    const Elf64_Phdr = std.elf.Elf64_Phdr;
    const image_base: u64 = 0x400000;
    const header_size = @sizeOf(Elf64_Ehdr) + 2 * @sizeOf(Elf64_Phdr);
    const phdr1_start = @sizeOf(Elf64_Ehdr) + @sizeOf(Elf64_Phdr);
    const phdr1 = std.mem.bytesAsValue(
        Elf64_Phdr,
        bytes[phdr1_start .. phdr1_start + @sizeOf(Elf64_Phdr)],
    );
    const source_field_vaddr = image_base + header_size + 1;
    const target_vaddr = phdr1.p_vaddr;
    const expected: i32 = @intCast(@as(i64, @intCast(target_vaddr)) - @as(i64, @intCast(source_field_vaddr + 4)));
    const patched = std.mem.readInt(i32, bytes[header_size + 1 .. header_size + 5][0..4], .little);

    try std.testing.expectEqual(expected, patched);
}

test "elf engine resolves payload addresses" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const text = try engine.segment(.{
        .kind = .text,
        .flags = .{ .read = true, .execute = true },
    });
    const data = try engine.segment(.{
        .kind = .data,
        .flags = .{ .read = true, .write = true },
    });

    _ = try engine.append(text, "code");
    _ = try engine.append(data, "A");
    try engine.setEntry(text, 0);

    const addr = try engine.payloadVirtualAddress(data, 0);

    const bytes = try engine.finalize();
    defer std.testing.allocator.free(bytes);

    const Elf64_Ehdr = std.elf.Elf64_Ehdr;
    const Elf64_Phdr = std.elf.Elf64_Phdr;
    const phdr1_start = @sizeOf(Elf64_Ehdr) + @sizeOf(Elf64_Phdr);
    const phdr1 = std.mem.bytesAsValue(
        Elf64_Phdr,
        bytes[phdr1_start .. phdr1_start + @sizeOf(Elf64_Phdr)],
    );

    try std.testing.expectEqual(phdr1.p_vaddr, addr);
}

test "elf engine reserves bss outside the file image" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const text = try engine.segment(.{
        .kind = .text,
        .flags = .{ .read = true, .execute = true },
    });
    const data = try engine.segment(.{
        .kind = .data,
        .flags = .{ .read = true, .write = true },
    });

    _ = try engine.append(text, "code");
    _ = try engine.append(data, "A");
    _ = try engine.reserveBss(data, 30_000);
    try engine.setEntry(text, 0);

    const bytes = try engine.finalize();
    defer std.testing.allocator.free(bytes);

    const Elf64_Ehdr = std.elf.Elf64_Ehdr;
    const Elf64_Phdr = std.elf.Elf64_Phdr;
    const phdr1_start = @sizeOf(Elf64_Ehdr) + @sizeOf(Elf64_Phdr);
    const phdr1 = std.mem.bytesAsValue(
        Elf64_Phdr,
        bytes[phdr1_start .. phdr1_start + @sizeOf(Elf64_Phdr)],
    );

    try std.testing.expectEqual(@as(u64, 1), phdr1.p_filesz);
    try std.testing.expectEqual(@as(u64, 30_001), phdr1.p_memsz);
}

test "elf engine resolves virtual addresses inside bss" {
    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    const text = try engine.segment(.{
        .kind = .text,
        .flags = .{ .read = true, .execute = true },
    });
    const data = try engine.segment(.{
        .kind = .data,
        .flags = .{ .read = true, .write = true },
    });

    _ = try engine.append(text, "code");
    _ = try engine.reserveBss(data, 64);
    try engine.setEntry(text, 0);

    const base = try engine.payloadVirtualAddress(data, 0);
    const tail = try engine.payloadVirtualAddress(data, 63);

    try std.testing.expectEqual(base + 63, tail);
}
