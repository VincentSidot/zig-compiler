const std = @import("std");

const helper = @import("../../../helper.zig");
const eprintf = helper.eprintf;

const lib_file = @import("../../lib.zig");
const opcode = @import("../../opcode.zig");

pub const pop = opcode.pop;
pub const EncodingError = lib_file.EncodingError;

pub const RegisterIndex_64 = lib_file.RegisterIndex_64;
pub const RegisterMemory_64 = lib_file.RegisterMemory_64;

fn print_buffer(comptime prefix: []const u8, buff: []const u8) void {
    eprintf("  {s}: ", .{prefix});
    for (buff) |byte| {
        eprintf("{x:02} ", .{byte});
    }
    eprintf("\n", .{});
}

fn fn_pop(comptime Dest: type) type {
    return fn (writer: *std.io.Writer, dest: Dest) EncodingError!usize;
}

pub fn validate(
    comptime Dest: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn_pop(Dest),
    dest: Dest,
) !void {
    var buffer: [16]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    const written = try tested(&writer, dest);

    if (written != expected.len) {
        eprintf("\n[POP validation failed] {s}\n", .{name});
        print_buffer("Actual", buffer[0..written]);
        print_buffer("Expected", expected);
        eprintf("  Length mismatch: expected {d} byte(s), got {d} byte(s)\n", .{ expected.len, written });
        return error.InvalidEncodingLength;
    }

    if (!std.mem.eql(u8, buffer[0..written], expected)) {
        eprintf("\n[POP validation failed] {s}\n", .{name});
        print_buffer("Actual", buffer[0..written]);
        print_buffer("Expected", expected);
        return error.InvalidEncodingData;
    }
}

test "POP Summary" {
    const pop_64 = @import("64.zig");

    const pop_64_tests = pop_64.validate_calls.load(.monotonic);
    const pop_total_tests = pop_64_tests;

    eprintf(
        "POP Summary: 64={d:03} total={d:03}\n",
        .{ pop_64_tests, pop_total_tests },
    );
}
