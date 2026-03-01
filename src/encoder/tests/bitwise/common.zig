const std = @import("std");

const helper = @import("../../../helper.zig");
const eprintf = helper.eprintf;

const lib_file = @import("../../lib.zig");
const opcode = @import("../../opcode.zig");

pub const bitand = opcode.bitand;
pub const bitor = opcode.bitor;
pub const bitxor = opcode.bitxor;
pub const EncodingError = lib_file.EncodingError;

pub const RegisterIndex_64 = lib_file.RegisterIndex_64;
pub const RegisterIndex_32 = lib_file.RegisterIndex_32;
pub const RegisterIndex_16 = lib_file.RegisterIndex_16;
pub const RegisterIndex_8 = lib_file.RegisterIndex_8;

pub const RegisterMemory_64 = lib_file.RegisterMemory_64;
pub const RegisterMemory_32 = lib_file.RegisterMemory_32;
pub const RegisterMemory_16 = lib_file.RegisterMemory_16;
pub const RegisterMemory_8 = lib_file.RegisterMemory_8;

fn print_buffer(comptime prefix: []const u8, buff: []const u8) void {
    eprintf("  {s}: ", .{prefix});
    for (buff) |byte| {
        eprintf("{x:02} ", .{byte});
    }
    eprintf("\n", .{});
}

fn fn_logic(comptime Dest: type, comptime Src: type) type {
    return fn (writer: *std.io.Writer, dest: Dest, source: Src) EncodingError!usize;
}

pub fn validate(
    comptime Dest: type,
    comptime Src: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn_logic(Dest, Src),
    dest: Dest,
    source: Src,
) !void {
    var buffer: [16]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    const written = try tested(&writer, dest, source);

    if (written != expected.len) {
        eprintf("\n[BITWISE validation failed] {s}\n", .{name});
        print_buffer("Actual", buffer[0..written]);
        print_buffer("Expected", expected);
        eprintf("  Length mismatch: expected {d} byte(s), got {d} byte(s)\n", .{ expected.len, written });
        return error.InvalidEncodingLength;
    }

    if (!std.mem.eql(u8, buffer[0..written], expected)) {
        eprintf("\n[BITWISE validation failed] {s}\n", .{name});
        print_buffer("Actual", buffer[0..written]);
        print_buffer("Expected", expected);
        return error.InvalidEncodingData;
    }
}

test "BITWISE Summary" {
    const bitwise_8 = @import("8.zig");
    const bitwise_16 = @import("16.zig");
    const bitwise_32 = @import("32.zig");
    const bitwise_64 = @import("64.zig");

    const bitwise_8_tests = bitwise_8.validate_calls.load(.monotonic);
    const bitwise_16_tests = bitwise_16.validate_calls.load(.monotonic);
    const bitwise_32_tests = bitwise_32.validate_calls.load(.monotonic);
    const bitwise_64_tests = bitwise_64.validate_calls.load(.monotonic);
    const bitwise_total_tests = bitwise_8_tests + bitwise_16_tests + bitwise_32_tests + bitwise_64_tests;

    eprintf(
        "BITWISE Summary: 8={d:03} 16={d:03} 32={d:03} 64={d:03} total={d:03}\n",
        .{ bitwise_8_tests, bitwise_16_tests, bitwise_32_tests, bitwise_64_tests, bitwise_total_tests },
    );
}
