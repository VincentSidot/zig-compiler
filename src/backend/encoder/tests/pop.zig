const std = @import("std");

const pop_64 = @import("pop/64.zig");
const common = @import("pop/common.zig");

test {
    std.testing.refAllDecls(pop_64);
    std.testing.refAllDecls(common);
}
