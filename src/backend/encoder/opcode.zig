const std = @import("std");
const enc_error = @import("error.zig");
const helper = @import("helper.zig");

const factory_file = @import("factory.zig");
const write_byte = factory_file.write_byte;
const write_bytes = factory_file.write_bytes;

const Writer = std.Io.Writer;
const EncodingError = enc_error.EncodingError;
const RetKind = helper.RetKind;

// Operations that can be used in the assembly code.

pub const add = @import("opcode/add.zig");
pub const sub = @import("opcode/sub.zig");
pub const cmp = @import("opcode/cmp.zig");
pub const call = @import("opcode/call.zig");
pub const jmp = @import("opcode/jmp.zig");
pub const jcc = @import("opcode/jcc.zig");
pub const push = @import("opcode/push.zig");
pub const pop = @import("opcode/pop.zig");
pub const lea = @import("opcode/lea.zig");
pub const bitand = @import("opcode/bitand.zig");
pub const bitor = @import("opcode/bitor.zig");
pub const bitxor = @import("opcode/bitxor.zig");
pub const test_op = @import("opcode/test.zig");
pub const @"test" = test_op;
pub const mov = @import("opcode/mov.zig");
pub const inc = @import("opcode/inc.zig");
pub const dec = @import("opcode/dec.zig");

pub fn syscall(writer: ?*Writer) EncodingError!usize {
    const SYSCALL_OPCODE = [2]u8{
        0x0F,
        0x05,
    };

    const written: usize = 2; // syscall number for write
    try write_bytes(writer, &SYSCALL_OPCODE);

    return written;
}

pub fn ret(writer: ?*Writer, kind: RetKind) EncodingError!usize {
    const RET_OPCODE_NEAR: u8 = 0xC3;
    const RET_OPCODE_FAR: u8 = 0xCB;

    var opcode: u8 = undefined;

    if (kind == RetKind.Near or kind == RetKind.Default) {
        opcode = RET_OPCODE_NEAR;
    } else {
        opcode = RET_OPCODE_FAR;
    }

    const written: usize = 1; // syscall number for write
    try write_byte(writer, opcode);

    return written;
}
