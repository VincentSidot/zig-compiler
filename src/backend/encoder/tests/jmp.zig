const std = @import("std");

const jmp_64 = @import("jmp/64.zig");
const common = @import("jmp/common.zig");

test {
    std.testing.refAllDecls(jmp_64);
    std.testing.refAllDecls(common);
}
