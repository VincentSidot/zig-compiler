// Standard library imports
const std = @import("std");
const RawArgs = std.process.Args;
const Allocator = std.mem.Allocator;

// Helper function for printing logic
const helper = @import("helper.zig");
const printf = helper.printf;
const eprintf = helper.eprintf;

pub const Args = struct {
    pub const Mode = enum { interpret, jit, elf };

    input_path: []const u8,
    output_path: ?[]const u8 = null,
    mode: Mode = .jit,
    measure_time: bool = false,

    allocator: Allocator,

    pub fn init(raw: RawArgs, allocator: Allocator) !?Args {
        const args = try raw.toSlice(allocator);
        defer allocator.free(args);

        return parseArgs(args, allocator);
    }

    pub fn deinit(self: Args) void {
        self.allocator.free(self.input_path);

        if (self.output_path) |path| {
            self.allocator.free(path);
        }
    }
};

fn parseArgs(args: []const []const u8, allocator: Allocator) !?Args {
    var parsed = Args{
        .input_path = "",
        .allocator = allocator,
    };

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printHelp();
            return null;
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--time")) {
            parsed.measure_time = true;
            continue;
        } else if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            i += 1;
            if (i >= args.len) {
                eprintf("Missing value for {s}\n", .{arg});
                return error.MissingOutputPath;
            }

            parsed.output_path = try allocator.dupe(u8, args[i]);
            errdefer allocator.free(parsed.output_path.?);

            continue;
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--mode")) {
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
            } else if (std.mem.eql(u8, mode_arg, "elf")) {
                parsed.mode = .elf;
            } else {
                eprintf("Invalid mode: {s}. Expected one of: interpret, jit\n", .{mode_arg});
                return error.InvalidMode;
            }
            continue;
        } else if (std.mem.startsWith(u8, arg, "-")) {
            eprintf("Unknown argument: {s}\n", .{arg});
            return error.InvalidArgument;
        } else if (parsed.input_path.len != 0) {
            eprintf("Only one input file is supported. Got extra: {s}\n", .{arg});
            return error.InvalidArgument;
        }

        parsed.input_path = try allocator.dupe(u8, arg);
        errdefer allocator.free(parsed.input_path);
    }

    if (parsed.input_path.len == 0) {
        eprintf("Missing input brainfuck file path.\n", .{});
        return error.MissingInputPath;
    }

    if (parsed.mode == .elf and parsed.output_path == null) {
        eprintf("Output path is required in elf mode.\n", .{});
        return error.MissingOutputPath;
    }

    return parsed;
}

fn printHelp() void {
    printf(
        \\Usage: program [options] <input.bf>
        \\
        \\Options:
        \\  -h, --help            Show this help message
        \\  -m, --mode <mode>     Choose execution mode: interpret | jit (default: jit) | elf
        \\  -o, --output <path>   Write compiled machine code to file (mandatory for elf mode)
        \\  -t, --time            Measure execution time
        \\
    , .{});
}
