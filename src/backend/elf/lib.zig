const std = @import("std");
const log = std.log;
const AsmEngine = @import("../engine/engine.zig").Engine;

pub const Engine = @import("engine.zig").Engine;
pub const EntryPoint = @import("engine.zig").EntryPoint;
pub const SegmentConfig = @import("engine.zig").SegmentConfig;
pub const SegmentFlags = @import("engine.zig").SegmentFlags;
pub const SegmentId = @import("engine.zig").SegmentId;
pub const SegmentKind = @import("engine.zig").SegmentKind;

test {
    std.testing.refAllDecls(@import("tests.zig"));
    std.testing.refAllDecls(@import("engine.zig"));
}
