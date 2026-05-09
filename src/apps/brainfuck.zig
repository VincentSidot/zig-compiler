//! A simple brainfuck interpreter and JIT interpreter.

const std = @import("std");
const log = std.log;

// Helper function for printing logic
const helper = @import("../helper.zig");
const logFunctionMake = helper.logFunctionMake;
const printf = helper.printf;
const eprintf = helper.eprintf;

const Brainfuck = @import("../brainfuck/lib.zig");

// Argument parsing logic
const Args = @import("../args.zig").Args;

// Define standard options for logging.
const disableLog: bool = false;
pub const std_options: std.Options = .{
    .logFn = logFunctionMake(1024, disableLog),
    .log_level = .debug,
};

pub fn start(init: std.process.Init) !void {
    const allocator = std.heap.smp_allocator;

    const args = Args.init(init.minimal.args, allocator) catch |err| {
        eprintf("Error parsing arguments: {}\n", .{err});
        return;
    } orelse {
        // If the arguments are null
        return;
    };
    defer args.deinit();

    const Clock = std.Io.Clock.cpu_process;
    const io = init.io;

    var start_time: ?std.Io.Timestamp = null;
    if (args.measure_time) {
        start_time = Clock.now(io);
    }

    var tape = [_]u8{0} ** 30_000;

    printf("Loading brainfuck code from file: {s}\n", .{args.input_path});

    var interpreter = try Brainfuck.load_file(io, allocator, args.input_path);
    defer interpreter.deinit();

    switch (args.mode) {
        .interpret => {
            printf("Interpreting brainfuck code...\n", .{});
            try interpreter.interpret(&tape);
        },
        .jit => {
            printf("Compiling brainfuck code to machine code...\n", .{});
            const compiled = try Brainfuck.compile(&interpreter);
            defer compiled.deinit();

            if (args.output_path) |path| {
                try write_file(io, path, compiled.raw);
                printf("Wrote compiled code to {s}\n", .{path});
            }

            printf("Executing brainfuck code...\n", .{});
            try compiled.execute(&tape);
        },
        .elf => {
            printf("Generating ELF executable from brainfuck code...\n", .{});
            try generate_elf(
                io,
                allocator,
                &interpreter,
                args.output_path orelse unreachable,
            );
        },
    }

    if (start_time) |_start| {
        const elapsed = _start.untilNow(io, Clock);
        const elapsedMs = elapsed.toMilliseconds();

        if (elapsedMs < 100) {
            const elapsedUs = elapsed.toMicroseconds();
            if (elapsedUs < 100) {
                const elapsedNs = elapsed.toNanoseconds();
                log.info("Execution time: {d} ns", .{elapsedNs});
            } else {
                log.info("Execution time: {d} µs", .{elapsedUs});
            }
        } else {
            log.info("Execution time: {d} ms", .{elapsedMs});
        }
    }
}

fn write_file(io: std.Io, path: []const u8, data: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir| {
        if (dir.len > 0) {
            try std.Io.Dir.cwd().createDirPath(io, dir);
        }
    }

    var file: std.Io.File = undefined;

    if (std.fs.path.isAbsolute(path)) {
        if (std.Io.Dir.path.dirname(path)) |dir| {
            try std.Io.Dir.createDirAbsolute(io, dir, .default_dir);
        }

        file = try std.Io.Dir.createFileAbsolute(io, path, .{ .truncate = true });
    } else {
        if (std.fs.path.dirname(path)) |dir| {
            try std.Io.Dir.cwd().createDirPath(io, dir);
        }

        file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    }
    defer file.close(io);

    try file.writeStreamingAll(io, data);
}

fn generate_elf(
    io: std.Io,
    allocator: std.mem.Allocator,
    interpreter: *Brainfuck.BrainfuckInterpreter,
    output_path: []const u8,
) !void {
    const AsmEngine = @import("../asm/engine.zig");
    const ElfEngine = @import("../elf/engine.zig");

    log.debug("Compile brainfuck code to machine code for ELF generation...\n", .{});
    var asm_engine = AsmEngine.init(allocator);
    defer asm_engine.deinit();

    const TAPE_SIZE: usize = 30_000;
    const TAPE_SYM = try asm_engine.symbol();

    const ENTRY_LABEL = try asm_engine.label();

    // Generate the code

    asm_engine.mov(.rdi, .{
        .sym = .{ .id = TAPE_SYM, .kind = .abs64 },
    });
    // Call the entry point of the compiled brainfuck code
    asm_engine.call(.{ .label = ENTRY_LABEL });
    // Now exit cleanly with syscall exit(0)
    asm_engine.xor(.rdi, .rdi); // exit code 0
    asm_engine.mov(.rax, .immediate(60)); // syscall number for exit
    asm_engine.syscall();

    try asm_engine.bind(ENTRY_LABEL);
    try Brainfuck.compile_with_engine(
        allocator,
        interpreter.program,
        &asm_engine,
    );

    try asm_engine.finalize();

    const text_code = try asm_engine.takeBytes();
    defer allocator.free(text_code);

    var elf_engine = ElfEngine.init(allocator);
    defer elf_engine.deinit();

    const text = try elf_engine.segment(.{
        .kind = .text,
        .flags = .{ .read = true, .execute = true },
    });

    const data = try elf_engine.segment(.{
        .kind = .data,
        .flags = .{ .read = true, .write = true },
    });

    _ = try elf_engine.append(text, text_code);
    _ = try elf_engine.reserveBss(data, TAPE_SIZE);

    const data_virtual_address = try elf_engine.payloadVirtualAddress(data, 0);
    const text_address = try elf_engine.payloadSlice(text, 0);

    try asm_engine.patch(
        text_address,
        TAPE_SYM,
        data_virtual_address,
    );

    try elf_engine.setEntry(text, 0);

    var file = try std.Io.Dir.cwd().createFile(
        io,
        output_path,
        .{ .truncate = true },
    );
    defer file.close(io);

    const file_size = try elf_engine.finalizeToFile(io, file);
    log.info("Generated ELF executable: {s} ({d} bytes)\n", .{ output_path, file_size });
}
