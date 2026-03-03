const std = @import("std");
const log = std.log;

// Helper function for printing logic
const helper = @import("helper.zig");
const logFunctionMake = helper.logFunctionMake;
const printf = helper.printf;
const eprintf = helper.eprintf;

// Define standard options for logging.
const disableLog: bool = false;
pub const std_options: std.Options = .{
    .logFn = logFunctionMake(1024, disableLog),
    .log_level = .debug,
};

const CliArgs = struct {
    const Mode = enum {
        interpret,
        jit,
    };

    input_path: []const u8,
    output_path: ?[]const u8 = null,
    mode: Mode = .jit,
    show_help: bool = false,
};

pub fn main() !void {
    const allocator = std.heap.smp_allocator;
    const brainfuck = @import("brainfuck/lib.zig");
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    const cli_args = try parseArgs(args);

    if (cli_args.show_help) {
        printHelp();
        return;
    }

    var tape = [_]u8{0} ** 30_000;

    printf("Loading brainfuck code from file: {s}\n", .{cli_args.input_path});

    var interpreter = try brainfuck.load_file(allocator, cli_args.input_path);
    defer interpreter.deinit();

    switch (cli_args.mode) {
        .interpret => {
            printf("Interpreting brainfuck code...\n", .{});
            try interpreter.interpret(&tape);
        },
        .jit => {
            printf("Compiling brainfuck code to machine code...\n", .{});
            const compiled = try brainfuck.compile(&interpreter);
            defer compiled.deinit();

            if (cli_args.output_path) |path| {
                try write_file(path, compiled.raw);
                printf("Wrote compiled code to {s}\n", .{path});
            }

            printf("Executing brainfuck code...\n", .{});
            try compiled.execute(&tape);
        },
    }
}

fn parseArgs(args: []const []const u8) !CliArgs {
    var parsed = CliArgs{ .input_path = "" };

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            parsed.show_help = true;
            continue;
        }

        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= args.len) {
                eprintf("Missing value for {s}\n", .{arg});
                return error.MissingOutputPath;
            }
            parsed.output_path = args[i];
            continue;
        }

        if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--mode")) {
            i += 1;
            if (i >= args.len) {
                eprintf("Missing value for {s}\n", .{arg});
                return error.MissingModeValue;
            }

            const mode_arg = args[i];
            if (std.mem.eql(u8, mode_arg, "interpret")) {
                parsed.mode = .interpret;
            } else if (std.mem.eql(u8, mode_arg, "jit")) {
                parsed.mode = .jit;
            } else {
                eprintf("Invalid mode: {s}. Expected one of: interpret, jit\n", .{mode_arg});
                return error.InvalidMode;
            }
            continue;
        }

        if (std.mem.startsWith(u8, arg, "-")) {
            eprintf("Unknown argument: {s}\n", .{arg});
            return error.InvalidArgument;
        }

        if (parsed.input_path.len != 0) {
            eprintf("Only one input file is supported. Got extra: {s}\n", .{arg});
            return error.InvalidArgument;
        }

        parsed.input_path = arg;
    }

    if (parsed.show_help) return parsed;

    if (parsed.input_path.len == 0) {
        eprintf("Missing input brainfuck file path.\n", .{});
        return error.MissingInputPath;
    }

    return parsed;
}

fn printHelp() void {
    printf(
        \\Usage: rce [options] <input.bf>
        \\
        \\Options:
        \\  -h, --help            Show this help message
        \\  -m, --mode <mode>     Choose execution mode: interpret | jit (default: jit)
        \\  -o, --output <path>   Write compiled machine code to file
        \\
    , .{});
}

fn write_file(path: []const u8, data: []const u8) !void {
    if (std.fs.path.dirname(path)) |dir| {
        if (dir.len > 0) {
            try std.fs.cwd().makePath(dir);
        }
    }

    const file = if (std.fs.path.isAbsolute(path))
        try std.fs.createFileAbsolute(path, .{ .truncate = true })
    else
        try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();

    try file.writeAll(data);
}
