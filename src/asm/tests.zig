const std = @import("std");

const mov = @import("tests/mov.zig");
const labels = @import("tests/labels.zig");
const instructions = @import("tests/instructions.zig");

test {
    std.testing.refAllDecls(mov);
    std.testing.refAllDecls(labels);
    std.testing.refAllDecls(instructions);
}
