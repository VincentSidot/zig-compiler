const std = @import("std");
const log = std.log;

const op_file = @import("../op.zig");
const Arg = op_file.Arg;
const BranchTarget = op_file.BranchTarget;
const Condition = op_file.Condition;
const Label = op_file.Label;
const Memory = op_file.Memory;

const helper_file = @import("../../encoder/helper.zig");
const patch = helper_file.patch;
const O = helper_file.OFFSETS;

const encoder = @import("../../encoder/lib.zig");
const opcode = encoder.opcode;

pub const LabelInfo = struct {
    offset: ?usize = null,
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
    writer: *std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    target: BranchTarget,
) !void {
    switch (target) {
        .label => |label| try rel32Label(writer, written, allocator, fixups, label, .jmp),
        .rel => |rel| written.* += try opcode.jmp.rel32(writer, rel),
        .reg => |reg| {
            const r64 = reg.as_reg64() orelse {
                log.debug("jmp indirect register target must be a 64-bit register", .{});
                return error.InvalidOperand;
            };
            written.* += try opcode.jmp.r64(writer, r64);
        },
        .mem => |mem| {
            const rm64 = try qwordMemory(mem);
            written.* += try opcode.jmp.rm64(writer, rm64);
        },
    }
}

pub fn call(
    writer: *std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    target: BranchTarget,
) !void {
    switch (target) {
        .label => |label| try rel32Label(writer, written, allocator, fixups, label, .call),
        .rel => |rel| written.* += try opcode.call.rel32(writer, rel),
        .reg => |reg| {
            const r64 = reg.as_reg64() orelse {
                log.debug("call indirect register target must be a 64-bit register", .{});
                return error.InvalidOperand;
            };
            written.* += try opcode.call.r64(writer, r64);
        },
        .mem => |mem| {
            const rm64 = try qwordMemory(mem);
            written.* += try opcode.call.rm64(writer, rm64);
        },
    }
}

pub fn jcc(
    writer: *std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    condition: Condition,
    target: BranchTarget,
) !void {
    switch (target) {
        .label => |label| try jccLabel(writer, written, allocator, fixups, condition, label),
        .rel => |rel| written.* += try opcode.jcc.rel32(writer, condition, rel),
        .reg => {
            log.debug("jcc does not support register targets; use a label or relative displacement", .{});
            return error.InvalidOperand;
        },
        .mem => {
            log.debug("jcc does not support memory targets; use a label or relative displacement", .{});
            return error.InvalidOperand;
        },
    }
}

fn jccLabel(
    writer: *std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    condition: Condition,
    target: Label,
) !void {
    // Use only 32-bit for now.
    const offset = written.*;
    written.* += try opcode.jcc.rel32(writer, condition, 0);
    try fixups.append(allocator, .{
        .label = target,
        .base_offset = offset,
        .kind = .jcc,
        .size = ._32,
    });
}

const Rel32Op = enum {
    jmp,
    call,
};

fn rel32Label(
    writer: *std.Io.Writer,
    written: *usize,
    allocator: std.mem.Allocator,
    fixups: *std.ArrayList(Fixup),
    target: Label,
    op: Rel32Op,
) !void {
    // Use only 32-bit for now.
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

fn qwordMemory(mem: Memory) !encoder.RegisterMemory_64 {
    if (mem.size != .qword) {
        log.debug("indirect branch memory target must be qword sized", .{});
        return error.InvalidOperand;
    }

    return (try (Arg{ .mem = mem }).as_mem64()) orelse {
        log.debug("failed to convert indirect branch memory target to encoder rm64 operand", .{});
        return error.InvalidOperand;
    };
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
