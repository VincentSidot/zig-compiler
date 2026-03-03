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

pub fn main() !void {
    const allocator = std.heap.smp_allocator;
    const brainfuck = @import("brainfuck/lib.zig");
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var output_path: ?[]const u8 = null;
    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= args.len) return error.MissingOutputPath;
            output_path = args[i];
            continue;
        }

        return error.InvalidArgument;
    }

    var tape = [_]u8{0} ** 30_000;

    printf("Loading brainfuck code from file...\n", .{});

    var interpreter = try brainfuck.load_file(allocator, "brainfuck/hello.bf");
    defer interpreter.deinit();

    printf("Interpreting brainfuck code...\n", .{});

    try interpreter.interpret(&tape);

    printf("Done interpreting brainfuck code.\n", .{});

    printf("Compiling brainfuck code to machine code...\n", .{});
    // Compile the brainfuck code to machine code.
    const compiled = try brainfuck.compile(&interpreter);
    defer compiled.deinit();

    if (output_path) |path| {
        try write_file(path, compiled.raw);
        printf("Wrote compiled code to {s}\n", .{path});
    }

    printf("Executing brainfuck code...\n", .{});

    @memset(&tape, 0);
    compiled.execute(&tape);

    printf("Done executing brainfuck code.\n", .{});
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
