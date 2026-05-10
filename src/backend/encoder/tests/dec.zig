const std = @import("std");

const dec_all = @import("dec/all.zig");
const common = @import("dec/common.zig");

test {
    std.testing.refAllDecls(dec_all);
    std.testing.refAllDecls(common);
}
