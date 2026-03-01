const std = @import("std");

const add_8 = @import("add/8.zig");
const add_16 = @import("add/16.zig");
const add_32 = @import("add/32.zig");
const add_64 = @import("add/64.zig");

const common = @import("add/common.zig");

test {
    std.testing.refAllDecls(add_8);
    std.testing.refAllDecls(add_16);
    std.testing.refAllDecls(add_32);
    std.testing.refAllDecls(add_64);

    std.testing.refAllDecls(common);
}
