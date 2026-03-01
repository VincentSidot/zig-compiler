const std = @import("std");

const lea_16 = @import("lea/16.zig");
const lea_32 = @import("lea/32.zig");
const lea_64 = @import("lea/64.zig");
const common = @import("lea/common.zig");

test {
    std.testing.refAllDecls(lea_16);
    std.testing.refAllDecls(lea_32);
    std.testing.refAllDecls(lea_64);
    std.testing.refAllDecls(common);
}
