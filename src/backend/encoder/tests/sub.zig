const std = @import("std");

const sub_8 = @import("sub/8.zig");
const sub_16 = @import("sub/16.zig");
const sub_32 = @import("sub/32.zig");
const sub_64 = @import("sub/64.zig");

const common = @import("sub/common.zig");

test {
    std.testing.refAllDecls(sub_8);
    std.testing.refAllDecls(sub_16);
    std.testing.refAllDecls(sub_32);
    std.testing.refAllDecls(sub_64);

    std.testing.refAllDecls(common);
}
