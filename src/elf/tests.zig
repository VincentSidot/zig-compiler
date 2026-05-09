const std = @import("std");

const engine = @import("tests/engine.zig");

test {
    std.testing.refAllDecls(engine);
}
