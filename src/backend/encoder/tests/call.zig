const std = @import("std");

const call_64 = @import("call/64.zig");
const common = @import("call/common.zig");

test {
    std.testing.refAllDecls(call_64);
    std.testing.refAllDecls(common);
}
