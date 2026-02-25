const std = @import("std");

const helper = @import("../../../helper.zig");
const eprintf = helper.eprintf;

const lib_file = @import("../../lib.zig");
const mov_file = @import("../../mov.zig");

pub const mov = mov_file.mov;
pub const EncodingError = lib_file.EncodingError;

// Index registers
pub const RegisterIndex_64 = lib_file.RegisterIndex_64;
pub const RegisterIndex_32 = lib_file.RegisterIndex_32;
pub const RegisterIndex_16 = lib_file.RegisterIndex_16;
pub const RegisterIndex_8 = lib_file.RegisterIndex_8;
// Memory operands
pub const RegisterMemory_64 = lib_file.RegisterMemory_64;
pub const RegisterMemory_32 = lib_file.RegisterMemory_32;
pub const RegisterMemory_16 = lib_file.RegisterMemory_16;
pub const RegisterMemory_8 = lib_file.RegisterMemory_8;

fn print_buffer(comptime prefix: []const u8, buff: []const u8) void {
    eprintf(prefix ++ ": ", .{});
    for (buff) |byte| {
        eprintf("{x:02} ", .{byte});
    }
    eprintf("\n", .{});
}

fn fn_mov(comptime Dest: type, comptime Src: type) type {
    return fn (writer: *std.io.Writer, dest: Dest, source: Src) EncodingError!usize;
}

pub fn validate(
    comptime Dest: type,
    comptime Src: type,
    comptime name: []const u8,
    comptime expected: []const u8,
    tested: fn_mov(Dest, Src),
    dest: Dest,
    source: Src,
) !void {
    eprintf("Validating MOV \"{s}\" instruction: ", .{name});

    var buffer: [16]u8 = undefined;
    var writer = std.io.Writer.fixed(&buffer);

    const writen = try tested(&writer, dest, source);

    print_buffer("", buffer[0..writen]);

    if (writen != expected.len) {
        eprintf("Expected {d} bytes but got {d}\n", .{ expected.len, writen });
        return error.InvalidEncodingLength;
    }

    if (!std.mem.eql(u8, buffer[0..writen], expected)) {
        print_buffer("Expected", expected);
        return error.InvalidEncodingData;
    }
}
