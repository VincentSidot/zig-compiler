const std = @import("std");

const jcc_rel = @import("jcc/rel.zig");
const common = @import("jcc/common.zig");

test {
    std.testing.refAllDecls(jcc_rel);
    std.testing.refAllDecls(common);
}
