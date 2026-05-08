const std = @import("std");

const inc_all = @import("inc/all.zig");
const common = @import("inc/common.zig");

test {
    std.testing.refAllDecls(inc_all);
    std.testing.refAllDecls(common);
}
