const std = @import("std");

const test_8 = @import("test/8.zig");
const common = @import("test/common.zig");

test {
    std.testing.refAllDecls(test_8);
    std.testing.refAllDecls(common);
}
