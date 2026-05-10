const std = @import("std");
const helper = @import("../../../helper.zig");
const eprintf = helper.eprintf;

const mov_8 = @import("mov/8.zig");
const mov_16 = @import("mov/16.zig");
const mov_32 = @import("mov/32.zig");
const mov_64 = @import("mov/64.zig");

const common = @import("mov/common.zig");

test {
    std.testing.refAllDecls(mov_8);
    std.testing.refAllDecls(mov_16);
    std.testing.refAllDecls(mov_32);
    std.testing.refAllDecls(mov_64);

    std.testing.refAllDecls(common);
}
