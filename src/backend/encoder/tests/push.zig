const std = @import("std");

const push_64 = @import("push/64.zig");
const common = @import("push/common.zig");

test {
    std.testing.refAllDecls(push_64);
    std.testing.refAllDecls(common);
}
