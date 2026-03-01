const std = @import("std");

const cmp_8 = @import("cmp/8.zig");
const cmp_16 = @import("cmp/16.zig");
const cmp_32 = @import("cmp/32.zig");
const cmp_64 = @import("cmp/64.zig");

const common = @import("cmp/common.zig");

test {
    std.testing.refAllDecls(cmp_8);
    std.testing.refAllDecls(cmp_16);
    std.testing.refAllDecls(cmp_32);
    std.testing.refAllDecls(cmp_64);

    std.testing.refAllDecls(common);
}
