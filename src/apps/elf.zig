//! Simple hello world elf emitter.

const std = @import("std");
const log = std.log;

const AsmEngine = @import("../asm/engine.zig").Engine;
const ElfEngine = @import("../elf/engine.zig").Engine;

/// Generates a tiny example ELF executable with one RX text segment and one RW data segment.
pub fn generate(io: std.Io) !void {
    const allocator = std.heap.smp_allocator;
    const data_segment = "Hello, World!\n";

    var asm_engine = AsmEngine.init(allocator);
    defer asm_engine.deinit();
    const data_symbol = try asm_engine.symbol();

    asm_engine.mov(.rax, AsmEngine.Arg.unsigned(1));
    asm_engine.mov(.rdi, AsmEngine.Arg.unsigned(1));
    asm_engine.mov(.rsi, AsmEngine.Arg.sym64(data_symbol));
    asm_engine.mov(.rdx, AsmEngine.Arg.unsigned(data_segment.len));
    asm_engine.syscall();

    asm_engine.mov(.rax, AsmEngine.Arg.unsigned(60));
    asm_engine.xor(.edi, .edi);
    asm_engine.syscall();

    try asm_engine.finalize();
    const text_code = try asm_engine.takeBytes();
    defer allocator.free(text_code);

    var engine = ElfEngine.init(allocator);
    defer engine.deinit();

    const text = try engine.segment(.{
        .kind = .text,
        .flags = .{ .read = true, .execute = true },
    });
    const data = try engine.segment(.{
        .kind = .data,
        .flags = .{ .read = true, .write = true },
    });

    _ = try engine.append(text, text_code);
    _ = try engine.append(data, data_segment);

    const data_virtual_address = try engine.payloadVirtualAddress(data, 0);
    const text_address = try engine.payloadSlice(text, 0);

    try engine.setEntry(text, 0);
    try asm_engine.patch(
        text_address,
        data_symbol,
        data_virtual_address,
    );

    var file = try std.Io.Dir.cwd().createFile(io, "output.elf", .{ .truncate = true });
    defer file.close(io);

    const file_size = try engine.finalizeToFile(io, file);
    log.info("ELF file generated successfully, size: {d} bytes", .{file_size});
}
