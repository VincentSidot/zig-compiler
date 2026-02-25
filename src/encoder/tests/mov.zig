const std = @import("std");

const mov_8 = @import("mov/8.zig");
const mov_16 = @import("mov/16.zig");
const mov_32 = @import("mov/32.zig");
const mov_64 = @import("mov/64.zig");

test {
    std.testing.refAllDecls(mov_8);
    // They are deactivated during the mov_factory rework, to be updated later
    // std.testing.refAllDecls(mov_16);
    // std.testing.refAllDecls(mov_32);
    // std.testing.refAllDecls(mov_64);
}
