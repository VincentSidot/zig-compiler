const std = @import("std");

const bitwise_8 = @import("bitwise/8.zig");
const bitwise_16 = @import("bitwise/16.zig");
const bitwise_32 = @import("bitwise/32.zig");
const bitwise_64 = @import("bitwise/64.zig");

const common = @import("bitwise/common.zig");

test {
    std.testing.refAllDecls(bitwise_8);
    std.testing.refAllDecls(bitwise_16);
    std.testing.refAllDecls(bitwise_32);
    std.testing.refAllDecls(bitwise_64);

    std.testing.refAllDecls(common);
}
