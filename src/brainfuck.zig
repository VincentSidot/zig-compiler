const std = @import("std");
const log = std.log;

// Helper function for printing logic
const helper = @import("helper.zig");
const logFunctionMake = helper.logFunctionMake;
const printf = helper.printf;
const eprintf = helper.eprintf;

// Argument parsing logic
const Args = @import("args.zig").Args;

// Define standard options for logging.
const disableLog: bool = false;
pub const std_options: std.Options = .{
    .logFn = logFunctionMake(1024, disableLog),
    .log_level = .debug,
};

pub fn start(init: std.process.Init) !void {
    const allocator = std.heap.smp_allocator;
    const brainfuck = @import("brainfuck/lib.zig");

    const args = try Args.init(init.minimal.args, allocator) orelse {
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

    var interpreter = try brainfuck.load_file(io, allocator, args.input_path);
    defer interpreter.deinit();

    switch (args.mode) {
        .interpret => {
            printf("Interpreting brainfuck code...\n", .{});
            try interpreter.interpret(&tape);
        },
        .jit => {
            printf("Compiling brainfuck code to machine code...\n", .{});
            const compiled = try brainfuck.compile(&interpreter);
            defer compiled.deinit();

            if (args.output_path) |path| {
                try write_file(io, path, compiled.raw);
                printf("Wrote compiled code to {s}\n", .{path});
            }

            printf("Executing brainfuck code...\n", .{});
            try compiled.execute(&tape);
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
