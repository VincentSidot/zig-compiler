const std = @import("std");

const op_file = @import("../op.zig");
const ir = @import("../ir.zig");
const Arg = op_file.Arg;
const CallTarget = op_file.CallTarget;
const Condition = op_file.Condition;
const JccTarget = op_file.JccTarget;
const JumpTarget = op_file.JumpTarget;
const Label = op_file.Label;

const helper_file = @import("../../encoder/helper.zig");
const patch = helper_file.patch;
const O = helper_file.OFFSETS;

const encoder = @import("../../encoder/lib.zig");
const opcode = encoder.opcode;

pub const LabelInfo = struct {
    offset: ?usize = null,
    bound: bool = false,
};

pub const FixupKind = enum {
    jmp,
    jcc,
};

pub const FixupSize = enum {
    _8,
    _32,
};

pub const Fixup = struct {
    label: Label,
    base_offset: usize,
    kind: FixupKind,
    size: FixupSize,
};

pub fn jmp(
    writer: ?*std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    target: JumpTarget,
    encoding: ?ir.BranchEncoding,
) !void {
    switch (target) {
        .label => |label| try jmpLabel(writer, written, allocator, fixups, label, encoding),
        .rel => |rel| written.* += try opcode.jmp.rel32(writer, rel),
        .reg => |reg| written.* += try opcode.jmp.r64(writer, reg.as_encoder()),
        .mem => |mem| {
            const rm64 = try qwordMemory(mem);
            written.* += try opcode.jmp.rm64(writer, rm64);
        },
    }
}

pub fn call(
    writer: ?*std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    target: CallTarget,
) !void {
    switch (target) {
        .label => |label| try rel32Label(writer, written, allocator, fixups, label, .call),
        .rel => |rel| written.* += try opcode.call.rel32(writer, rel),
        .reg => |reg| written.* += try opcode.call.r64(writer, reg.as_encoder()),
        .mem => |mem| {
            const rm64 = try qwordMemory(mem);
            written.* += try opcode.call.rm64(writer, rm64);
        },
    }
}

pub fn jcc(
    writer: ?*std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    condition: Condition,
    target: JccTarget,
    encoding: ?ir.BranchEncoding,
) !void {
    switch (target) {
        .label => |label| try jccLabel(writer, written, allocator, fixups, condition, label, encoding),
        .rel => |rel| written.* += try opcode.jcc.rel32(writer, condition, rel),
    }
}

fn jmpLabel(
    writer: ?*std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    target: Label,
    encoding: ?ir.BranchEncoding,
) !void {
    const offset = written.*;
    const size: FixupSize = switch (encoding orelse .rel32) {
        .rel8 => blk: {
            written.* += try opcode.jmp.rel8(writer, 0);
            break :blk ._8;
        },
        .rel32 => blk: {
            written.* += try opcode.jmp.rel32(writer, 0);
            break :blk ._32;
        },
    };

    try fixups.append(allocator, .{
        .label = target,
        .base_offset = offset,
        .kind = .jmp,
        .size = size,
    });
}

fn jccLabel(
    writer: ?*std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    condition: Condition,
    target: Label,
    encoding: ?ir.BranchEncoding,
) !void {
    const offset = written.*;
    const size: FixupSize = switch (encoding orelse .rel32) {
        .rel8 => blk: {
            written.* += try opcode.jcc.rel8(writer, condition, 0);
            break :blk ._8;
        },
        .rel32 => blk: {
            written.* += try opcode.jcc.rel32(writer, condition, 0);
            break :blk ._32;
        },
    };

    try fixups.append(allocator, .{
        .label = target,
        .base_offset = offset,
        .kind = .jcc,
        .size = size,
    });
}

const Rel32Op = enum {
    jmp,
    call,
};

fn rel32Label(
    writer: ?*std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    target: Label,
    op: Rel32Op,
) !void {
    const offset = written.*;
    written.* += switch (op) {
        .jmp => try opcode.jmp.rel32(writer, 0),
        .call => try opcode.call.rel32(writer, 0),
    };

    try fixups.append(allocator, .{
        .label = target,
        .base_offset = offset,
        .kind = .jmp,
        .size = ._32,
    });
}

fn qwordMemory(mem: op_file.BranchMemory) !encoder.RegisterMemory_64 {
    return (try (Arg{ .mem = mem.as_memory() }).as_mem64()) orelse return error.InvalidOperand;
}

pub fn resolve_fixups(
    bytes: []u8,
    fixups: []const Fixup,
    labels: []const LabelInfo,
) !void {
    for (fixups) |fixup| {
        const label_info = labels[fixup.label.index];

        if (label_info.offset == null) return error.UnresolvedLabel;

        const target_offset = label_info.offset.?;
        const patch_offset = fixup.base_offset;

        switch (fixup.size) {
            ._8 => {
                try patch(i8, O.O1_REL8, O.O2_REL8, bytes, patch_offset, target_offset);
            },
            ._32 => {
                const o1 = switch (fixup.kind) {
                    .jcc => O.O1_JCC_REL32,
                    .jmp => O.O1_JMP_REL32,
                };
                const o2 = switch (fixup.kind) {
                    .jcc => O.O2_JCC_REL32,
                    .jmp => O.O2_JMP_REL32,
                };
                try patch(i32, o1, o2, bytes, patch_offset, target_offset);
            },
        }
    }
}
