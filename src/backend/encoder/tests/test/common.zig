const std = @import("std");

const helper = @import("../../../../helper.zig");
const eprintf = helper.eprintf;

const lib_file = @import("../../lib.zig");
const opcode = @import("../../opcode.zig");

pub const test_op = opcode.test_op;
pub const EncodingError = lib_file.EncodingError;

pub const RegisterIndex_8 = lib_file.RegisterIndex_8;
pub const RegisterMemory_8 = lib_file.RegisterMemory_8;

fn print_buffer(comptime prefix: []const u8, buff: []const u8) void {
    eprintf("  {s}: ", .{prefix});
    for (buff) |byte| {
        eprintf("{x:02} ", .{byte});
    }
    eprintf("\n", .{});
}

fn fn_test(comptime Dest: type, comptime Src: type) type {
    return fn (writer: *std.Io.Writer, dest: Dest, source: Src) EncodingError!usize;
}

pub fn validate(
    comptime Dest: type,
    comptime Src: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn_test(Dest, Src),
    dest: Dest,
    source: Src,
) !void {
    var buffer: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);

    const written = try tested(&writer, dest, source);

    if (written != expected.len) {
        eprintf("\n[TEST validation failed] {s}\n", .{name});
        print_buffer("Actual", buffer[0..written]);
        print_buffer("Expected", expected);
        eprintf("  Length mismatch: expected {d} byte(s), got {d} byte(s)\n", .{ expected.len, written });
        return error.InvalidEncodingLength;
    }

    if (!std.mem.eql(u8, buffer[0..written], expected)) {
        eprintf("\n[TEST validation failed] {s}\n", .{name});
        print_buffer("Actual", buffer[0..written]);
        print_buffer("Expected", expected);
        return error.InvalidEncodingData;
    }
}
